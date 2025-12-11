package edu.uth.hr_service.Controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping; 
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import edu.uth.hr_service.Model.Employee;
import edu.uth.hr_service.Service.EmployeeService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor
public class EmployeeController {

    private final EmployeeService employeeService;

    // API Tạo nhân viên
    // Cách gọi: POST /api/employees?departmentId=5
    // Body: { "fullName": "Nguyen Van A", "email": "a@gmail.com", ... }
    @PostMapping
    public ResponseEntity<Employee> createEmployee(
            @RequestBody Employee employee, 
            @RequestParam(required = false) Long departmentId // <--- Thêm dòng này để nhận ID phòng ban từ URL
    ) {
        // 1. Giả sử lấy companyId từ Token (hardcode = 1)
        Long companyId = 1L; 
        
        // 2. Gọi Service 
        Employee created = employeeService.createEmployee(employee, companyId, departmentId);
        
        // 3. Trả về kết quả (Biến created đã được định nghĩa ở trên)
        return ResponseEntity.ok(created);
    }
}