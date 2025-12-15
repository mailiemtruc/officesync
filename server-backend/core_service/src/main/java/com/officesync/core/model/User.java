package com.officesync.core.model;

import java.time.LocalDate;
import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "users") // Khớp với tên bảng trong MySQL
@Data
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String password; // Lưu ý: Spring Security thích dùng field tên password

    @Column(name = "full_name")
    private String fullName;
    
    // Lưu Role (SUPER_ADMIN, COMPANY_ADMIN...)
    @Column(name = "role")
    private String role; 

    @Column(name = "company_id")
    private Long companyId;

    // --- CÁC TRƯỜNG MỚI BỔ SUNG ---
    @Column(name = "mobile_number")
    private String mobileNumber;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    // Các trường phục vụ Quên mật khẩu
    @Column(name = "otp_code")
    private String otpCode;
    
    @Column(name = "otp_expiry")
    private LocalDateTime otpExpiry;

    @Column(columnDefinition = "ENUM('ACTIVE', 'LOCKED') DEFAULT 'ACTIVE'")
    private String status = "ACTIVE";
}