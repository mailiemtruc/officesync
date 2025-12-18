package com.officesync.hr_service.Controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Repository.EmployeeRepository;
import com.officesync.hr_service.Service.EmployeeService;

import lombok.Data;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;

    // [DTO MỚI] Dùng class này để hứng JSON từ Flutter (vì Employee gốc không có password)
    @Data
    public static class CreateEmployeeRequest {
        private String fullName;
        private String email;
        private String phone;
        private String dateOfBirth; // Nhận dạng String "yyyy-MM-dd"
        private String role;
        private String password;    // [QUAN TRỌNG] Hứng mật khẩu
    }

    @PostMapping
    public ResponseEntity<Employee> createEmployee(
            @RequestHeader("X-User-Id") Long creatorId,
            @RequestBody CreateEmployeeRequest request, // Sử dụng DTO
            @RequestParam(required = false) Long departmentId
    ) {
        // 1. Tìm thông tin người tạo
        Employee creator = employeeRepository.findById(creatorId)
                .orElseThrow(() -> new RuntimeException("Creator not found: " + creatorId));
        
        Long companyId = creator.getCompanyId(); 
        
        // 2. Chuyển đổi DTO -> Entity Employee
        Employee newEmployee = new Employee();
        newEmployee.setFullName(request.getFullName());
        newEmployee.setEmail(request.getEmail());
        newEmployee.setPhone(request.getPhone());
        
        // Xử lý ngày sinh (String -> LocalDate)
        if (request.getDateOfBirth() != null && !request.getDateOfBirth().isEmpty()) {
            try {
               newEmployee.setDateOfBirth(java.time.LocalDate.parse(request.getDateOfBirth()));
            } catch (Exception e) {
               // Log error nếu cần
            }
        }
        
        // Xử lý Role
        try {
            newEmployee.setRole(com.officesync.hr_service.Model.EmployeeRole.valueOf(request.getRole()));
        } catch (Exception e) {
            newEmployee.setRole(com.officesync.hr_service.Model.EmployeeRole.STAFF);
        }

        // 3. Gọi Service (Truyền password riêng)
        Employee created = employeeService.createEmployee(
            newEmployee, 
            companyId, 
            departmentId, 
            request.getPassword() // [QUAN TRỌNG] Lấy password từ DTO truyền vào Service
        );
        
        return ResponseEntity.ok(created);
    }
}