package com.officesync.hr_service.Service;

import java.util.List;
import java.util.Optional;
import java.util.Random;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.DTO.EmployeeSyncEvent; // [MỚI] Import DTO
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Producer.EmployeeProducer; // [MỚI] Import Producer
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeProducer employeeProducer; // [MỚI] Inject Producer để bắn RabbitMQ

   @Transactional
    public Department createDepartmentFull(String name, String description, Long managerId, List<Long> memberIds, Long companyId) {
        // 1. Khởi tạo đối tượng
        Department dept = new Department();
        dept.setName(name);
        dept.setDescription(description);
        dept.setCompanyId(companyId);
        
        // [KHÔI PHỤC] Tự động sinh màu
        dept.setColor(generateRandomColor());

        // [KHÔI PHỤC] Lưu lần đầu bằng hàm Retry của bạn để có ID và Code
        Department savedDept = saveDepartmentWithRetry(dept);
        
        if (savedDept == null) {
            throw new RuntimeException("Không thể tạo phòng ban.");
        }

        // 2. Xử lý Manager (Logic chuyển phòng/thăng chức chuẩn doanh nghiệp)
        if (managerId != null) {
            Employee newManager = employeeRepository.findById(managerId)
                    .orElseThrow(() -> new RuntimeException("Manager not found"));

            // Kiểm tra xem ông này có đang làm quản lý phòng KHÁC không?
            Optional<Department> oldManagedDeptOpt = departmentRepository.findByManagerId(managerId);
            if (oldManagedDeptOpt.isPresent()) {
                Department oldDept = oldManagedDeptOpt.get();
                // Nếu đúng là quản lý phòng cũ -> Gỡ quyền bên đó
                if (!oldDept.getId().equals(savedDept.getId())) {
                    oldDept.setManager(null);
                    departmentRepository.save(oldDept);
                    log.info("--> Đã gỡ quyền quản lý của {} tại phòng cũ {}", newManager.getEmail(), oldDept.getName());
                }
            }

            // Gán vào phòng mới
            newManager.setDepartment(savedDept);
            
            // Thăng chức lên MANAGER (nếu chưa phải)
            if (newManager.getRole() != EmployeeRole.MANAGER) {
                newManager.setRole(EmployeeRole.MANAGER);
            }
            
            // Lưu & Đồng bộ RabbitMQ
            employeeRepository.save(newManager);
            syncEmployeeToCore(newManager);

            // Cập nhật lại department
            savedDept.setManager(newManager);
        }

        // 3. Xử lý Members
        if (memberIds != null && !memberIds.isEmpty()) {
            List<Employee> members = employeeRepository.findAllById(memberIds);
            for (Employee emp : members) {
                // Bỏ qua nếu trùng với ông Manager vừa chọn
                if (managerId != null && emp.getId().equals(managerId)) {
                    continue;
                }

                // Nếu ông này đang làm Manager ở đâu đó -> Giáng chức xuống STAFF
                if (emp.getRole() == EmployeeRole.MANAGER) {
                    Optional<Department> oldDept = departmentRepository.findByManagerId(emp.getId());
                    if (oldDept.isPresent()) {
                        oldDept.get().setManager(null);
                        departmentRepository.save(oldDept.get());
                    }
                    emp.setRole(EmployeeRole.STAFF);
                }

                emp.setDepartment(savedDept);
                employeeRepository.save(emp);
                syncEmployeeToCore(emp);
            }
        }

        // Lưu lần cuối (Để cập nhật Manager vào bảng Department)
        return departmentRepository.save(savedDept);
    }

    // 2. Bổ nhiệm Quản lý (Có đồng bộ Core)
    @Transactional
    public Department assignManager(Long departmentId, Long employeeId) {
        Department department = departmentRepository.findById(departmentId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy phòng ban"));

        Employee newManager = employeeRepository.findById(employeeId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy nhân viên"));

        // Cập nhật phòng ban
        if (newManager.getDepartment() == null || !newManager.getDepartment().getId().equals(departmentId)) {
            newManager.setDepartment(department);
        }

        // Thăng chức lên MANAGER
        boolean roleChanged = false;
        if (newManager.getRole() == EmployeeRole.STAFF) {
            newManager.setRole(EmployeeRole.MANAGER);
            roleChanged = true;
        }

        // Lưu DB
        Employee savedManager = employeeRepository.save(newManager);
        department.setManager(savedManager);
        
        // [QUAN TRỌNG] Đồng bộ sang Core Service
        if (roleChanged) {
            syncEmployeeToCore(savedManager);
        }

        return departmentRepository.save(department);
    }

  

    // [MỚI] Hàm đóng gói sự kiện và gửi sang RabbitMQ
    private void syncEmployeeToCore(Employee emp) {
        try {
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                emp.getEmail(),
                emp.getFullName(),
                emp.getPhone(),
                emp.getDateOfBirth(),
                emp.getCompanyId(),
                emp.getRole().name(), // Quan trọng: Gửi Role mới (MANAGER/STAFF)
                emp.getStatus().name(),
                null // Password không đổi thì để null
            );
            
            // Gọi Producer
            employeeProducer.sendEmployeeUpdatedEvent(event);
            log.info("--> [SYNC] Đã gửi sự kiện cập nhật quyền cho User: {} -> Role: {}", emp.getEmail(), emp.getRole());
            
        } catch (Exception e) {
            log.error("Lỗi khi đồng bộ quyền sang Core Service: {}", e.getMessage());
        }
    }

    private String generateRandomColor() {
        Random random = new Random();
        int nextInt = random.nextInt(0xffffff + 1);
        return String.format("#%06x", nextInt);
    }
    
    private Department saveDepartmentWithRetry(Department department) {
        int maxRetries = 3; 
        for (int i = 0; i < maxRetries; i++) {
            try {
                department.setDepartmentCode(generateRandomDeptCode());
                return departmentRepository.save(department);
            } catch (DataIntegrityViolationException e) {
                log.warn("Đụng độ mã phòng ban: {}. Retry lần {}...", department.getDepartmentCode(), i + 1);
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Hệ thống bận, không thể tạo phòng ban lúc này.");
                }
            }
        }
        return null;
    }

    private String generateRandomDeptCode() {
        int randomNum = (int) (Math.random() * 10000); 
        return String.format("DEP%04d", randomNum);
    }

    public List<Department> getAllDepartments() {
        return departmentRepository.findAll();
    }

   @Transactional
public Department updateDepartment(Long deptId, String name, String description, Long managerId) {
    Department currentDept = departmentRepository.findById(deptId)
            .orElseThrow(() -> new RuntimeException("Department not found"));

    currentDept.setName(name);
    currentDept.setDescription(description);

    // Xử lý thay đổi Manager
    if (managerId != null) {
        // Kiểm tra xem Manager mới có khác Manager hiện tại không
        // (Nếu managerId gửi lên trùng với người đang làm quản lý thì không cần làm gì cả)
        boolean isDifferentManager = currentDept.getManager() == null || !currentDept.getManager().getId().equals(managerId);

        if (isDifferentManager) {
            
            // --- BƯỚC 1: XỬ LÝ NGƯỜI QUẢN LÝ CŨ (HẠ CHỨC & ĐỒNG BỘ) ---
            Employee oldManager = currentDept.getManager();
            if (oldManager != null) {
                // Hạ chức xuống STAFF
                oldManager.setRole(EmployeeRole.STAFF);
                // Lưu vào DB
                employeeRepository.save(oldManager);
                
                // [QUAN TRỌNG] Gửi RabbitMQ để Core Service biết ông này đã bị xuống chức
                syncEmployeeToCore(oldManager); 
                
                log.info("--> Đã giáng chức Manager cũ: {} xuống STAFF", oldManager.getEmail());
            }

            // --- BƯỚC 2: XỬ LÝ NGƯỜI QUẢN LÝ MỚI (THĂNG CHỨC & ĐỒNG BỘ) ---
            Employee newManager = employeeRepository.findById(managerId)
                    .orElseThrow(() -> new RuntimeException("Manager not found"));

            // [FIX LỖI] Kiểm tra xem ông này có đang làm quản lý ở phòng KHÁC không?
            Optional<Department> oldManagedDeptOpt = departmentRepository.findByManagerId(managerId);
            if (oldManagedDeptOpt.isPresent()) {
                Department oldDept = oldManagedDeptOpt.get();
                if (!oldDept.getId().equals(deptId)) {
                    oldDept.setManager(null);
                    departmentRepository.saveAndFlush(oldDept);
                    log.info("Đã gỡ quyền quản lý của user {} tại phòng cũ {}", managerId, oldDept.getName());
                }
            }

            // Chuyển Manager mới về phòng ban này
            newManager.setDepartment(currentDept);
            
            // Thăng chức lên MANAGER (nếu chưa phải)
            if (newManager.getRole() != EmployeeRole.MANAGER) {
                newManager.setRole(EmployeeRole.MANAGER);
                // [QUAN TRỌNG] Gửi RabbitMQ để Core Service biết ông này lên chức
                // Lưu ý: syncEmployeeToCore sẽ được gọi ở dưới sau khi save
            }
            
            // Lưu Manager mới
            employeeRepository.save(newManager);
            syncEmployeeToCore(newManager); // Đồng bộ sang Core
            
            // Gán vào phòng mới
            currentDept.setManager(newManager);
        }
    } else {
        // Trường hợp gửi managerId = null (Bãi nhiệm quản lý, không bổ nhiệm ai)
        if (currentDept.getManager() != null) {
            Employee oldManager = currentDept.getManager();
            oldManager.setRole(EmployeeRole.STAFF); 
            employeeRepository.save(oldManager);
            
            // [QUAN TRỌNG] Đồng bộ việc hạ chức sang Core
            syncEmployeeToCore(oldManager);
            
            currentDept.setManager(null);
        }
    }

    return departmentRepository.save(currentDept);
}

    // [MỚI] Xóa phòng ban (Logic: Set nhân viên về Unassigned)
    @Transactional
    public void deleteDepartment(Long deptId) {
        Department dept = departmentRepository.findById(deptId)
                .orElseThrow(() -> new RuntimeException("Department not found"));

        // 1. Tìm tất cả nhân viên trong phòng ban này
        List<Employee> employees = employeeRepository.findByDepartmentId(deptId);
        
        // 2. Set Department = null và Role = STAFF (nếu là Manager)
        for (Employee emp : employees) {
            emp.setDepartment(null);
            if (emp.getRole() == EmployeeRole.MANAGER) {
                emp.setRole(EmployeeRole.STAFF);
                syncEmployeeToCore(emp); // Đồng bộ quyền về Core
            }
        }
        employeeRepository.saveAll(employees);

        // 3. Xóa phòng ban
        departmentRepository.delete(dept);
    }
}