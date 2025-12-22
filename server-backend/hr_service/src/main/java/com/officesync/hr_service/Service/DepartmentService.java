package com.officesync.hr_service.Service;

import java.util.List;
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

    // [MỚI] Hàm tạo phòng ban đầy đủ logic
    @Transactional
    public Department createDepartmentFull(String name, String description, Long managerId, List<Long> memberIds, Long companyId) {
        
        // 1. Khởi tạo phòng ban
        Department department = new Department();
        department.setName(name);
        department.setDescription(description);
        department.setCompanyId(companyId);
        
        // 2. Tạo màu ngẫu nhiên
        department.setColor(generateRandomColor());

        // 3. Lưu phòng ban trước
        Department savedDept = saveDepartmentWithRetry(department);

        // 4. Xử lý QUẢN LÝ (Nếu có chọn)
        if (managerId != null) {
            Employee newManager = employeeRepository.findById(managerId)
                    .orElseThrow(() -> new RuntimeException("Manager not found"));

            // Logic: Cập nhật phòng ban mới + Thăng chức lên MANAGER
            newManager.setDepartment(savedDept);
            boolean roleChanged = false;
            if (newManager.getRole() != EmployeeRole.MANAGER) {
                newManager.setRole(EmployeeRole.MANAGER);
                roleChanged = true;
            }
            
            Employee savedManager = employeeRepository.save(newManager);
            savedDept.setManager(savedManager);

            // [QUAN TRỌNG] Đồng bộ sang Core Service ngay nếu có thay đổi Role hoặc để đảm bảo nhất quán
            syncEmployeeToCore(savedManager); 
        }

        // 5. Xử lý THÀNH VIÊN (Nếu có chọn)
        if (memberIds != null && !memberIds.isEmpty()) {
            List<Employee> members = employeeRepository.findAllById(memberIds);
            for (Employee emp : members) {
                // Logic: Chuyển sang phòng ban mới
                emp.setDepartment(savedDept);
                
                // Logic: Nếu đang là MANAGER -> Xuống làm STAFF
                boolean roleChanged = false;
                if (emp.getRole() == EmployeeRole.MANAGER) {
                     emp.setRole(EmployeeRole.STAFF); 
                     roleChanged = true;
                }
                
                // Lưu vào DB
                Employee savedMember = employeeRepository.save(emp);

                // [QUAN TRỌNG] Nếu quyền bị hạ từ Manager -> Staff, cũng phải đồng bộ sang Core
                if (roleChanged) {
                    syncEmployeeToCore(savedMember);
                }
            }
        }

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
}