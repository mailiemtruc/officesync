package com.officesync.core.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.core.model.User;
import com.officesync.core.service.CompanyService;

@RestController
@RequestMapping("/api/company")
public class CompanyController {

    @Autowired private CompanyService companyService;

    @GetMapping("/me")
    @PreAuthorize("hasAnyAuthority('COMPANY_ADMIN', 'MANAGER', 'STAFF')")
    public ResponseEntity<?> getMyCompany(@AuthenticationPrincipal User user) {
        try {
            return ResponseEntity.ok(companyService.getMyCompany(user.getCompanyId()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PutMapping("/me")
    @PreAuthorize("hasAuthority('COMPANY_ADMIN')")
    public ResponseEntity<?> updateCompany(@AuthenticationPrincipal User user, @RequestBody Map<String, Object> req) {
        try {
            return ResponseEntity.ok(companyService.updateMyCompany(user.getCompanyId(), req));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
}