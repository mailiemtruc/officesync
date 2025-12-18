package com.officesync.hr_service.Controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader; // Import header
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Repository.EmployeeRepository; // Import repo
import com.officesync.hr_service.Service.DepartmentService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService departmentService;
    private final EmployeeRepository employeeRepository; // Inject EmployeeRepo

    // API: Tạo phòng ban (Đã cập nhật logic lấy CompanyId)
    @PostMapping
    public ResponseEntity<Department> createDepartment(
            @RequestHeader("X-User-Id") Long creatorId, // Lấy ID người tạo từ Header
            @RequestBody Department department
    ) {
        // 1. Tìm người tạo để xác định Company
        Employee creator = employeeRepository.findById(creatorId)
                .orElseThrow(() -> new RuntimeException("User not found with ID: " + creatorId));
        
        // 2. Lấy CompanyId
        Long companyId = creator.getCompanyId(); 
        
        // 3. Tạo phòng ban
        Department created = departmentService.createDepartment(department, companyId);
        
        // 4. (Tùy chọn) Nếu có Manager được gửi lên, Service đã xử lý mapping ở mức DB nếu JSON đúng chuẩn
        
        return ResponseEntity.ok(created);
    }

    // API: Lấy danh sách phòng ban
    @GetMapping
    public ResponseEntity<List<Department>> getAllDepartments() {
        return ResponseEntity.ok(departmentService.getAllDepartments());
    }

    // API: Bổ nhiệm trưởng phòng
    @PutMapping("/{deptId}/manager")
    public ResponseEntity<Department> assignManager(
            @PathVariable Long deptId,
            @RequestBody Map<String, Long> payload) {
        
        Long employeeId = payload.get("employeeId");
        Department updated = departmentService.assignManager(deptId, employeeId);
        return ResponseEntity.ok(updated);
    }
}