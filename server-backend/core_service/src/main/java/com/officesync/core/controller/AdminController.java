package com.officesync.core.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.core.service.CompanyService;
import com.officesync.core.service.UserService;

@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasAuthority('SUPER_ADMIN')")
public class AdminController {

    @Autowired private CompanyService companyService;
    @Autowired private UserService userService;

    @GetMapping("/stats")
    public ResponseEntity<?> getSystemStats() {
        return ResponseEntity.ok(companyService.getSystemStats());
    }

    @GetMapping("/companies")
    public ResponseEntity<?> getAllCompanies() {
        return ResponseEntity.ok(companyService.getAllCompanies());
    }

    @PutMapping("/companies/{id}/status")
    public ResponseEntity<?> updateCompanyStatus(@PathVariable Long id, @RequestBody Map<String, String> req) {
        try {
            companyService.updateCompanyStatus(id, req.get("status"));
            return ResponseEntity.ok("Company status updated");
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping("/companies/{id}")
    public ResponseEntity<?> getCompanyDetail(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(companyService.getCompanyDetail(id));
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }

    @GetMapping("/companies/{id}/users")
    public ResponseEntity<?> getCompanyUsers(@PathVariable Long id) {
        return ResponseEntity.ok(userService.getUsersByCompanyId(id));
    }

    @GetMapping("/companies/top")
    public ResponseEntity<?> getTopCompanies() {
        return ResponseEntity.ok(companyService.getTopCompanies());
    }

    @PutMapping("/users/{id}/status")
    public ResponseEntity<?> updateUserStatus(@PathVariable Long id, @RequestBody Map<String, String> req) {
        try {
            userService.updateUserStatus(id, req.get("status"));
            return ResponseEntity.ok("User status updated");
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }
}