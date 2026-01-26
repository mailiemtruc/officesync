package com.officesync.hr_service.Controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Repository.EmployeeRepository;
import com.officesync.hr_service.Service.DepartmentService;

import lombok.Data;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService departmentService;
    private final EmployeeRepository employeeRepository;

    @Data
    public static class CreateDepartmentRequest {
        private String name;
        private Long managerId;
        private List<Long> memberIds;
        private Boolean isHr;
    }

    // 2. Cập nhật API Create
    @PostMapping
    public ResponseEntity<?> createDepartment(
            @RequestHeader("X-User-Id") Long creatorId,
            @RequestBody CreateDepartmentRequest request
    ) {
        try {
            Employee creator = employeeRepository.findById(creatorId)
                    .orElseThrow(() -> new RuntimeException("User not found"));
            
            Department created = departmentService.createDepartmentFull(
                    creator, 
                    request.getName(), 
                    request.getManagerId(), 
                    request.getMemberIds(),
                    request.getIsHr() 
            );
            return ResponseEntity.ok(created);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

 @GetMapping
public ResponseEntity<List<Department>> getAllDepartments(@RequestHeader("X-User-Id") Long requesterId) {
    // 1. Query User ở Controller (rất nhanh, DB có cache cấp 1)
    Employee requester = employeeRepository.findById(requesterId)
            .orElseThrow(() -> new RuntimeException("User not found"));
            
    // 2. Truyền Object vào Service để Cache Key hoạt động
    return ResponseEntity.ok(departmentService.getAllDepartments(requester));
}

    @Data
    public static class UpdateDepartmentRequest {
        private String name;
        private Long managerId;
        private Boolean isHr; 
    }

    // 3. Cập nhật API Update
    @PutMapping("/{id}")
    public ResponseEntity<?> updateDepartment(
            @RequestHeader("X-User-Id") Long updaterId,
            @PathVariable Long id,
            @RequestBody UpdateDepartmentRequest request
    ) {
        try {
            Employee updater = employeeRepository.findById(updaterId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            Department updated = departmentService.updateDepartment(
                updater, 
                id, 
                request.getName(), 
                request.getManagerId(),
                request.getIsHr()
            );
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteDepartment(
            @RequestHeader("X-User-Id") Long deleterId, // Header bắt buộc
            @PathVariable Long id
    ) {
        try {
            Employee deleter = employeeRepository.findById(deleterId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            departmentService.deleteDepartment(deleter, id);
            return ResponseEntity.ok(Map.of("message", "Department deleted successfully"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/search")
    public ResponseEntity<List<Department>> searchDepartments(
            @RequestHeader("X-User-Id") Long requesterId,
            @RequestParam String keyword
    ) {
        List<Department> results = departmentService.searchDepartments(requesterId, keyword);
        return ResponseEntity.ok(results);
    }

   @GetMapping("/hr")
    public ResponseEntity<?> getHrDepartment(
            @RequestHeader("X-User-Id") Long requesterId
    ) {
        try {
            // 1. Query User tại Controller
            Employee requester = employeeRepository.findById(requesterId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            // 2. Truyền Object vào Service để kích hoạt Cache Key đúng chuẩn
            Department hrDept = departmentService.getHrDepartment(requester);
            
            return ResponseEntity.ok(hrDept);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}