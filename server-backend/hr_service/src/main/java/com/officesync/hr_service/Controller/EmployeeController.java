package com.officesync.hr_service.Controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping; 
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader; // [Mới]
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Repository.EmployeeRepository; // [Mới]
import com.officesync.hr_service.Service.EmployeeService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService employeeService;
    private final EmployeeRepository employeeRepository; // [Mới] Để tìm thông tin người tạo

    // API Tạo nhân viên
    @PostMapping
    public ResponseEntity<Employee> createEmployee(
            @RequestHeader("X-User-Id") Long creatorId, // [Quan trọng] Lấy ID người đang thao tác từ Header
            @RequestBody Employee employee, 
            @RequestParam(required = false) Long departmentId
    ) {
        // 1. Tìm thông tin người đang tạo (Ví dụ: HR Manager hoặc Admin công ty)
        // Vì RabbitMQ đã sync User từ Core sang Employee, nên ta tìm được họ trong bảng employees
        Employee creator = employeeRepository.findById(creatorId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy thông tin người dùng (Creator ID: " + creatorId + ")"));
        
        // 2. Lấy CompanyId của người tạo để gán cho nhân viên mới
        // Logic: Nhân viên mới phải cùng công ty với người tạo ra họ
        Long companyId = creator.getCompanyId(); 
        
        // 3. Gọi Service tạo nhân viên
        Employee created = employeeService.createEmployee(employee, companyId, departmentId);
        
        return ResponseEntity.ok(created);
    }
}