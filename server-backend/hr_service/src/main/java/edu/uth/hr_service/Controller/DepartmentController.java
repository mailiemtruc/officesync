package edu.uth.hr_service.Controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import edu.uth.hr_service.Model.Department;
import edu.uth.hr_service.Service.DepartmentService;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService departmentService;

    // API: Tạo phòng ban
 
    @PostMapping
    public ResponseEntity<Department> createDepartment(@RequestBody Department department) {
        // Giả lập lấy companyId từ Token = 1L
        Long companyId = 1L; 
        Department created = departmentService.createDepartment(department, companyId);
        return ResponseEntity.ok(created);
    }

    // API: Lấy danh sách phòng ban

    @GetMapping
    public ResponseEntity<List<Department>> getAllDepartments() {
        return ResponseEntity.ok(departmentService.getAllDepartments());
    }

    // API: Bổ nhiệm trưởng phòng

    // Body json: { "employeeId": 10 }
    @PutMapping("/{deptId}/manager")
    public ResponseEntity<Department> assignManager(
            @PathVariable Long deptId,
            @RequestBody Map<String, Long> payload) {
        
        Long employeeId = payload.get("employeeId");
        Department updated = departmentService.assignManager(deptId, employeeId);
        return ResponseEntity.ok(updated);
    }
}