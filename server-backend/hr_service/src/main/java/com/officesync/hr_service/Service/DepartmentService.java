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
        dept.setColor(generateRandomColor());
        
        Department savedDept = saveDepartmentWithRetry(dept);

        // 2. Xử lý Manager
        if (managerId != null) {
            Employee newManager = employeeRepository.findById(managerId)
                    .orElseThrow(() -> new RuntimeException("Manager not found"));

            if (!newManager.getCompanyId().equals(companyId)) {
                throw new RuntimeException("LỖI BẢO MẬT: Nhân viên này không thuộc công ty của bạn!");
            }

            Optional<Department> oldManagedDeptOpt = departmentRepository.findByManagerId(managerId);
            if (oldManagedDeptOpt.isPresent()) {
                Department oldDept = oldManagedDeptOpt.get();
                if (!oldDept.getId().equals(savedDept.getId())) {
                    oldDept.setManager(null);
                    departmentRepository.saveAndFlush(oldDept); 
                    log.info("--> Đã gỡ quyền quản lý của {} tại phòng cũ {}", newManager.getEmail(), oldDept.getName());
                }
            }

            newManager.setDepartment(savedDept);
            if (newManager.getRole() != EmployeeRole.MANAGER) {
                newManager.setRole(EmployeeRole.MANAGER);
            }
            
            employeeRepository.save(newManager);
            syncEmployeeToCore(newManager);
            savedDept.setManager(newManager);
        }

        // 3. Xử lý Members
        if (memberIds != null && !memberIds.isEmpty()) {
            List<Employee> members = employeeRepository.findAllById(memberIds);
            for (Employee emp : members) {
                if (!emp.getCompanyId().equals(companyId)) continue; 

                if (managerId != null && emp.getId().equals(managerId)) continue;

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

        return departmentRepository.save(savedDept);
    }

  

    // [MỚI] Hàm đóng gói sự kiện và gửi sang RabbitMQ
    private void syncEmployeeToCore(Employee emp) {
        try {
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                emp.getId(), // [MỚI] Bắt buộc thêm ID vào đầu tiên
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

   // =================================================================
    // 2. UPDATE PHÒNG BAN (VÁ LỖI BẢO MẬT)
    // =================================================================
    @Transactional
    public Department updateDepartment(Long deptId, String name, String description, Long managerId) {
        Department currentDept = departmentRepository.findById(deptId)
                .orElseThrow(() -> new RuntimeException("Department not found"));

        currentDept.setName(name);
        currentDept.setDescription(description);

        if (managerId != null) {
            boolean isDifferentManager = currentDept.getManager() == null || !currentDept.getManager().getId().equals(managerId);

            if (isDifferentManager) {
                // Xử lý Manager cũ (Hạ chức)
                Employee oldManager = currentDept.getManager();
                if (oldManager != null) {
                    oldManager.setRole(EmployeeRole.STAFF);
                    employeeRepository.save(oldManager);
                    syncEmployeeToCore(oldManager);
                }

                // Xử lý Manager mới
                Employee newManager = employeeRepository.findById(managerId)
                        .orElseThrow(() -> new RuntimeException("Manager not found"));

                // [SECURITY CHECK] Kiểm tra nhân viên mới có cùng công ty với phòng ban không?
                if (!newManager.getCompanyId().equals(currentDept.getCompanyId())) {
                    throw new RuntimeException("LỖI BẢO MẬT: Nhân viên được chọn không thuộc công ty này!");
                }

                // Xử lý gỡ quyền quản lý cũ của Manager mới (nếu có)
                Optional<Department> oldManagedDeptOpt = departmentRepository.findByManagerId(managerId);
                if (oldManagedDeptOpt.isPresent()) {
                    Department oldDept = oldManagedDeptOpt.get();
                    if (!oldDept.getId().equals(deptId)) {
                        oldDept.setManager(null);
                        departmentRepository.saveAndFlush(oldDept);
                    }
                }

                newManager.setDepartment(currentDept);
                if (newManager.getRole() != EmployeeRole.MANAGER) {
                    newManager.setRole(EmployeeRole.MANAGER);
                }
                
                employeeRepository.save(newManager);
                syncEmployeeToCore(newManager);
                
                currentDept.setManager(newManager);
            }
        } else {
            // Trường hợp bãi nhiệm (managerId = null)
            if (currentDept.getManager() != null) {
                Employee oldManager = currentDept.getManager();
                oldManager.setRole(EmployeeRole.STAFF); 
                employeeRepository.save(oldManager);
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

    // [MỚI] Hàm search chuẩn Service
    public List<Department> searchDepartments(Long requesterId, String keyword) {
        // 1. Logic nghiệp vụ: Xác thực người dùng
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 2. Logic nghiệp vụ: Chỉ search trong công ty của người đó (Data Isolation)
        return departmentRepository.searchDepartments(requester.getCompanyId(), keyword);
    }
}