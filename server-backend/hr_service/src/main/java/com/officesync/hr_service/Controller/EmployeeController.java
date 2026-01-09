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

import com.officesync.hr_service.Model.Employee; // Nhớ import List
import com.officesync.hr_service.Model.EmployeeRole;
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

   // DTO cho yêu cầu cập nhật
    @Data
    public static class UpdateEmployeeRequest {
        private String fullName;
        private String phone;
        private String dateOfBirth;
        private String avatarUrl;
        
      
        private String email; 
        
        // Các trường quản trị
        private String status;       // "ACTIVE", "LOCKED"
        private String role;         // "STAFF", "MANAGER"
        private Long departmentId;   // Chuyển phòng ban
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
            @RequestHeader("X-User-Id") Long updaterId, // [MỚI] Lấy ID người thực hiện
            @PathVariable Long id,
            @RequestBody UpdateEmployeeRequest request
    ) {
        try {
            // 1. Tìm thông tin người thực hiện (Updater)
            Employee updater = employeeRepository.findById(updaterId)
                    .orElseThrow(() -> new RuntimeException("Updater (User) not found"));

            // 2. Gọi Service truyền updater vào để kiểm tra quyền
            Employee updated = employeeService.updateEmployee(
                updater, // <--- Tham số quan trọng nhất
                id,
                request.getFullName(),
                request.getPhone(),
                request.getDateOfBirth(),
                request.getAvatarUrl(),
                request.getStatus(),
                request.getRole(),
                request.getDepartmentId(),
                request.getEmail()
            );
            return ResponseEntity.ok(updated);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
   @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteEmployee(
            @RequestHeader("X-User-Id") Long deleterId, // [1] Lấy ID người đang thao tác
            @PathVariable Long id // [2] ID của nhân viên bị xóa
    ) {
        try {
            // Bước 1: Tìm thông tin người thực hiện (Deleter)
            Employee deleter = employeeRepository.findById(deleterId)
                    .orElseThrow(() -> new RuntimeException("User not found (Deleter)"));

            // Bước 2: Gọi Service với 2 tham số để check quyền
            employeeService.deleteEmployee(deleter, id);
            
            return ResponseEntity.ok(Map.of("message", "Xóa nhân viên thành công"));
        } catch (RuntimeException e) {
            // Trả về lỗi 400 kèm thông báo lý do (ví dụ: "Truy cập bị từ chối...")
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
    public ResponseEntity<?> createEmployee(
            @RequestHeader("X-User-Id") Long creatorId,
            @RequestBody CreateEmployeeRequest request, 
            @RequestParam(required = false) Long departmentId
    ) {
        try {
            // 1. Tìm thông tin người tạo
            Employee creator = employeeRepository.findById(creatorId)
                    .orElseThrow(() -> new RuntimeException("Creator not found: " + creatorId));
            
            // 2. Chuyển đổi DTO -> Entity Employee
            Employee newEmployee = new Employee();
            newEmployee.setFullName(request.getFullName());
            newEmployee.setEmail(request.getEmail());
            newEmployee.setPhone(request.getPhone());
            
            if (request.getDateOfBirth() != null && !request.getDateOfBirth().isEmpty()) {
                try {
                   newEmployee.setDateOfBirth(java.time.LocalDate.parse(request.getDateOfBirth()));
                } catch (Exception e) {}
            }
            
            // Xử lý Role (Service sẽ ghi đè nếu là Manager)
            try {
                newEmployee.setRole(com.officesync.hr_service.Model.EmployeeRole.valueOf(request.getRole()));
            } catch (Exception e) {
                newEmployee.setRole(com.officesync.hr_service.Model.EmployeeRole.STAFF);
            }

            // 3. [SỬA] GỌI SERVICE - Truyền object 'creator'
            Employee created = employeeService.createEmployee(
                newEmployee, 
                creator,      // <--- Thay đổi quan trọng
                departmentId, 
                request.getPassword()
            );
            
            return ResponseEntity.ok(created);

        } catch (RuntimeException e) {
            // Bắt lỗi permission hoặc validate để trả về 400/403 cho rõ ràng
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }



    // API TÌM KIẾM NHÂN VIÊN (Đã chuẩn hóa)
    @GetMapping("/search")
    public ResponseEntity<List<Employee>> searchEmployees(
            @RequestHeader("X-User-Id") Long requesterId,
            @RequestParam String keyword
    ) {
        // Controller chỉ điều phối, không xử lý logic
        List<Employee> results = employeeService.searchEmployees(requesterId, keyword);
        
        return ResponseEntity.ok(results);
    }

    // [MỚI] API 2: TÌM KIẾM ĐỂ CHỌN (Select Manager / Add Member)
    // Logic: Active only, Exclude Me, Exclude Admin
    @GetMapping("/suggestion")
    public ResponseEntity<List<Employee>> searchEmployeeSuggestion(
            @RequestHeader("X-User-Id") Long requesterId,
            @RequestParam(defaultValue = "") String keyword
    ) {
        // Gọi hàm service dùng query searchStaffForSelection
        List<Employee> results = employeeService.searchStaff(requesterId, keyword);
        return ResponseEntity.ok(results);
    }

     // [MỚI - CHUẨN DOANH NGHIỆP] Lấy danh sách nhân viên theo Department ID
    @GetMapping("/department/{deptId}")
    public ResponseEntity<List<Employee>> getEmployeesByDepartment(@PathVariable Long deptId) {
        // Gọi Repository đã có sẵn hàm findByDepartmentId
        List<Employee> employees = employeeRepository.findByDepartmentId(deptId);
        return ResponseEntity.ok(employees);
    }

    // [MỚI] API kiểm tra quyền truy cập Attendance 
    @GetMapping("/check-hr-permission")
    public ResponseEntity<?> checkHrPermission(@RequestHeader("X-User-Id") Long requesterId) {
        try {
            Employee employee = employeeRepository.findById(requesterId)
                    .orElseThrow(() -> new RuntimeException("User not found"));

            boolean isCompanyAdmin = employee.getRole() == EmployeeRole.COMPANY_ADMIN;
            
            boolean isHrMember = false;
            if (employee.getDepartment() != null) {
                isHrMember = Boolean.TRUE.equals(employee.getDepartment().getIsHr());
            }
            
            // Trả về true nếu là Admin HOẶC là thành viên phòng HR
            return ResponseEntity.ok(Map.of(
                "canAccessAttendance", (isCompanyAdmin || isHrMember)
            ));

        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}