package com.officesync.core.controller;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.core.model.Company;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.UserRepository;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasAuthority('SUPER_ADMIN')") // Chỉ Super Admin được gọi
public class AdminController {

    @Autowired private CompanyRepository companyRepository;
    @Autowired private UserRepository userRepository;

    // 1. Dashboard Stats (Thống kê tổng)
    @GetMapping("/stats")
    public ResponseEntity<?> getSystemStats() {
        long totalCompanies = companyRepository.count();
        long totalUsers = userRepository.count();
        // Có thể thêm count Active/Locked companies nếu cần
        
        Map<String, Long> stats = new HashMap<>();
        stats.put("companies", totalCompanies);
        stats.put("users", totalUsers);
        
        return ResponseEntity.ok(stats);
    }

    // 2. Lấy danh sách công ty
    @GetMapping("/companies")
    public ResponseEntity<List<Company>> getAllCompanies() {
        return ResponseEntity.ok(companyRepository.findAll());
    }

    // 3. Update trạng thái công ty (Lock/Unlock)
    @PutMapping("/companies/{id}/status")
    public ResponseEntity<?> updateCompanyStatus(@PathVariable Long id, @RequestBody Map<String, String> req) {
        String status = req.get("status"); // "ACTIVE" hoặc "LOCKED"
        return companyRepository.findById(id).map(company -> {
            company.setStatus(status);
            companyRepository.save(company);
            return ResponseEntity.ok("Company status updated to " + status);
        }).orElse(ResponseEntity.notFound().build());
    }

    // 4. Lấy chi tiết 1 công ty (Để xem cập nhật mới nhất)
    @GetMapping("/companies/{id}")
    public ResponseEntity<?> getCompanyDetail(@PathVariable Long id) {
        return companyRepository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // 5. Lấy danh sách nhân viên của công ty đó (Phân cấp)
    @GetMapping("/companies/{id}/users")
    public ResponseEntity<?> getCompanyUsers(@PathVariable Long id) {
        // Chỉ trả về list user thuộc companyId này
        return ResponseEntity.ok(userRepository.findByCompanyId(id));
    }

    // 6. Tạo tài khoản Admin cho công ty (Nếu cần tạo thủ công)
    // Bạn có thể reuse logic register, nhưng set role cứng là COMPANY_ADMIN

    // API MỚI: Lấy Top 3 công ty có nhiều nhân viên nhất
    @GetMapping("/companies/top")
    public ResponseEntity<?> getTopCompanies() {
        List<Company> allCompanies = companyRepository.findAll();
        
        // Tạo list kết quả có chứa thông tin công ty + số lượng user
        List<Map<String, Object>> result = new ArrayList<>();
        
        for (Company c : allCompanies) {
            long userCount = userRepository.countByCompanyId(c.getId());
            
            Map<String, Object> map = new HashMap<>();
            map.put("id", c.getId());
            map.put("name", c.getName());
            map.put("domain", c.getDomain());
            map.put("status", c.getStatus());
            map.put("userCount", userCount); // Thêm userCount để frontend biết nếu cần
            result.add(map);
        }

        // Sắp xếp giảm dần theo userCount và lấy 3 phần tử đầu
        List<Map<String, Object>> top3 = result.stream()
                .sorted((c1, c2) -> Long.compare((long)c2.get("userCount"), (long)c1.get("userCount")))
                .limit(3)
                .collect(Collectors.toList());

        return ResponseEntity.ok(top3);
    }

    // API: Khóa/Mở khóa tài khoản User
    @PutMapping("/users/{id}/status")
    public ResponseEntity<?> updateUserStatus(@PathVariable Long id, @RequestBody Map<String, String> req) {
        String newStatus = req.get("status"); // "ACTIVE" hoặc "LOCKED"
        return userRepository.findById(id).map(user -> {
            user.setStatus(newStatus);
            userRepository.save(user);
            return ResponseEntity.ok("User status updated to " + newStatus);
        }).orElse(ResponseEntity.notFound().build());
    }
}