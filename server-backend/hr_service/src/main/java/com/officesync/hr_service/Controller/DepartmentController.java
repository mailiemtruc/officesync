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

import lombok.Data;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService departmentService;
    private final EmployeeRepository employeeRepository; // Inject EmployeeRepo

  // [MỚI] Class DTO để hứng dữ liệu tạo phòng ban phức tạp
    @Data
    public static class CreateDepartmentRequest {
        private String name;
        private String description;
        private Long managerId;       // ID của người được chọn làm Manager
        private List<Long> memberIds; // Danh sách ID nhân viên
    }

    @PostMapping
    public ResponseEntity<Department> createDepartment(
            @RequestHeader("X-User-Id") Long creatorId,
            @RequestBody CreateDepartmentRequest request // Sử dụng DTO mới
    ) {
        Employee creator = employeeRepository.findById(creatorId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        Long companyId = creator.getCompanyId();

        // Gọi Service xử lý toàn bộ logic
        Department created = departmentService.createDepartmentFull(
                request.getName(), 
                request.getDescription(), 
                request.getManagerId(), 
                request.getMemberIds(), 
                companyId
        );
        
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