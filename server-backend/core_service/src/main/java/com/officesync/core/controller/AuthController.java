package com.officesync.core.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal; // 🔴 Import mới
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.core.model.User;
import com.officesync.core.service.AuthService;

import lombok.AllArgsConstructor;
import lombok.Data;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired private AuthService authService;

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        try {
            return ResponseEntity.ok(authService.login(req));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PostMapping("/send-register-otp")
    public ResponseEntity<?> sendRegisterOtp(@RequestBody Map<String, String> req) {
        try {
            authService.sendRegisterOtp(req.get("email"), req.get("mobile"));
            return ResponseEntity.ok("OTP sent to email!");
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PostMapping("/verify-register-otp")
    public ResponseEntity<?> verifyRegisterOtp(@RequestBody Map<String, String> req) {
        try {
            authService.verifyRegisterOtp(req.get("email"), req.get("otp"));
            return ResponseEntity.ok("OTP is valid!");
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest req) {
        try {
            authService.register(req);
            return ResponseEntity.ok("Company created successfully!");
        } catch (RuntimeException e) {
            return ResponseEntity.internalServerError().body("Registration failed: " + e.getMessage());
        }
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<?> forgotPassword(@RequestBody Map<String, String> req) {
        try {
            authService.forgotPassword(req.get("email"));
            return ResponseEntity.ok("OTP sent!");
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<?> verifyOtp(@RequestBody Map<String, String> req) {
        try {
            authService.verifyForgotPasswordOtp(req.get("email"), req.get("otp"));
            return ResponseEntity.ok("OTP Verified!");
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PostMapping("/reset-password")
    public ResponseEntity<?> resetPassword(@RequestBody Map<String, String> req) {
        try {
            authService.resetPassword(req.get("email"), req.get("otp"), req.get("password"));
            return ResponseEntity.ok("Password reset successfully!");
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // 🔴 API MỚI: ĐỔI MẬT KHẨU CHỦ ĐỘNG (Khi đang đăng nhập)
    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(@AuthenticationPrincipal User user, @RequestBody ChangePasswordRequest req) {
        try {
            // Gọi service xử lý (có check lịch sử pass cũ)
            authService.changePassword(user.getId(), req.getCurrentPassword(), req.getNewPassword());
            return ResponseEntity.ok("Password changed successfully!");
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    // DTOs
    @Data public static class LoginRequest { private String email; private String password; }
    
    @Data public static class RegisterRequest {
        private String companyName; private String fullName; private String email;
        private String mobileNumber; private String dateOfBirth; private String password;
        private String otp;
    }
    
    // 🔴 DTO MỚI CHO CHANGE PASSWORD
    @Data public static class ChangePasswordRequest { 
        private String currentPassword; 
        private String newPassword; 
    }

    @Data @AllArgsConstructor public static class AuthResponse { private String token; private User user; private String companyName; }
}