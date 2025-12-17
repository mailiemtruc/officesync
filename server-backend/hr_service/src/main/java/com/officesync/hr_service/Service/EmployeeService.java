package com.officesync.hr_service.Service;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import com.officesync.hr_service.DTO.UserCreatedEvent;
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Model.EmployeeStatus;
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;

    // =================================================================
    // 1. LOGIC CHO API (Controller gọi hàm này)
    // =================================================================
    public Employee createEmployee(Employee newEmployee, Long companyId, Long departmentId) {
        newEmployee.setCompanyId(companyId);
        
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);

        if (departmentId != null) {
            Department dept = departmentRepository.findById(departmentId)
                    .orElseThrow(() -> new RuntimeException("Phòng ban không tồn tại với ID: " + departmentId));
            newEmployee.setDepartment(dept);
        }

        // Gọi hàm lưu an toàn
        return saveEmployeeWithRetry(newEmployee);
    }

    // =================================================================
    // 2. LOGIC CHO RABBITMQ (Consumer gọi hàm này)
    // =================================================================
    public void createEmployeeFromEvent(UserCreatedEvent event) {
        log.info("Bắt đầu đồng bộ User ID: {} từ Core Service...", event.getId());

        if (employeeRepository.existsById(event.getId())) {
            log.warn("Nhân viên ID {} đã tồn tại. Bỏ qua tạo mới.", event.getId());
            return;
        }

        Employee newEmployee = new Employee();
        // Gán ID từ Core Service
        newEmployee.setId(event.getId()); 
        newEmployee.setCompanyId(event.getCompanyId());
        newEmployee.setFullName(event.getFullName());
        newEmployee.setEmail(event.getEmail());
        newEmployee.setDateOfBirth(event.getDateOfBirth());
        newEmployee.setPhone(event.getMobileNumber());
        
        // Map Role
        try {
            newEmployee.setRole(EmployeeRole.valueOf(event.getRole()));
        } catch (Exception e) {
            newEmployee.setRole(EmployeeRole.STAFF);
        }

        // Map Status
        try {
            newEmployee.setStatus(EmployeeStatus.valueOf(event.getStatus()));
        } catch (Exception e) {
            newEmployee.setStatus(EmployeeStatus.ACTIVE);
        }

        // Lưu
        Employee saved = saveEmployeeWithRetry(newEmployee);
        if (saved != null) {
            log.info("Đã tạo thành công nhân viên từ Event: {}", saved.getFullName());
        }
    }

    // =================================================================
    // 3. HÀM DÙNG CHUNG (Sinh mã & Retry)
    // =================================================================
    private Employee saveEmployeeWithRetry(Employee employee) {
        int maxRetries = 3; 
        for (int i = 0; i < maxRetries; i++) {
            try {
                // Chỉ sinh mã nếu chưa có (đề phòng trường hợp update sau này)
                if (employee.getEmployeeCode() == null) {
                    employee.setEmployeeCode(generateRandomCode());
                }
                return employeeRepository.save(employee);
            } catch (DataIntegrityViolationException e) {
                log.warn("Đụng độ mã nhân viên: {}. Thử lại lần {}...", employee.getEmployeeCode(), i + 1);
                // Reset mã để vòng lặp sau sinh mã mới
                employee.setEmployeeCode(null); 
                
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Lỗi hệ thống: Không thể sinh mã nhân viên.");
                }
            }
        }
        return null;
    }

    private String generateRandomCode() {
        int randomNum = (int) (Math.random() * 1000000);
        return String.format("NV%06d", randomNum);
    }
}