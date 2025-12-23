package com.officesync.hr_service.Controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.hr_service.Model.Employee; // Nhớ import List
import com.officesync.hr_service.Repository.EmployeeRepository;
import com.officesync.hr_service.Service.EmployeeService; // [MỚI]

import lombok.Data;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository;

    @Data
    public static class UpdateEmployeeRequest {
        private String fullName;
        private String phone;
        private String dateOfBirth;
        private String avatarUrl; // [QUAN TRỌNG] Thêm trường này
    }
     
    @Data
    public static class CreateEmployeeRequest {
        private String fullName;
        private String email;
        private String phone;
        private String dateOfBirth; // Nhận dạng String "yyyy-MM-dd"
        private String role;
        private String password;    // [QUAN TRỌNG] Hứng mật khẩu
    }

   @PutMapping("/{id}")
    public ResponseEntity<?> updateEmployee(
            @PathVariable Long id,
            @RequestBody UpdateEmployeeRequest request
    ) {
        try {
            Employee updated = employeeService.updateEmployee(
                id,
                request.getFullName(),
                request.getPhone(),
                request.getDateOfBirth(),
                request.getAvatarUrl() // Truyền avatarUrl xuống Service
            );
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
   

    @GetMapping
    public ResponseEntity<List<Employee>> getEmployees(
            @RequestHeader("X-User-Id") Long requesterId
    ) {
        List<Employee> employees = employeeService.getAllEmployeesByRequester(requesterId);
        return ResponseEntity.ok(employees);
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