package com.officesync.core.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.core.model.Company;
import com.officesync.core.model.User;
import com.officesync.core.repository.CompanyRepository;

@RestController
@RequestMapping("/api/company")
public class CompanyController {

    @Autowired private CompanyRepository companyRepository;

    // 1. Lấy thông tin công ty của User đang đăng nhập
    @GetMapping("/me")
    @PreAuthorize("hasAnyAuthority('COMPANY_ADMIN', 'MANAGER', 'STAFF')")
    public ResponseEntity<?> getMyCompany(@AuthenticationPrincipal User user) {
        if (user.getCompanyId() == null) {
            return ResponseEntity.badRequest().body("User does not belong to any company");
        }
        return companyRepository.findById(user.getCompanyId())
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // 2. Update thông tin công ty (Logo, Name...) - Chỉ Admin Công ty
    @PutMapping("/me")
    @PreAuthorize("hasAuthority('COMPANY_ADMIN')")
    public ResponseEntity<?> updateCompany(@AuthenticationPrincipal User user, @RequestBody Company req) {
        return companyRepository.findById(user.getCompanyId()).map(company -> {
            company.setName(req.getName());
            // company.setLogoUrl(req.getLogoUrl()); // Cần thêm trường logoUrl vào Entity Company trước
            companyRepository.save(company);
            return ResponseEntity.ok(company);
        }).orElse(ResponseEntity.notFound().build());
    }
}