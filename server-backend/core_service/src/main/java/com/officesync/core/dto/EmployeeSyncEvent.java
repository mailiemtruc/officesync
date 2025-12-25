package com.officesync.core.dto;

import java.time.LocalDate;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class EmployeeSyncEvent {
    private String email;
    private String previousEmail;
    private String fullName;
    private String phone;
    private LocalDate dateOfBirth;
    private Long companyId;
    private String role;
    private String status;
    private String password; // Nhận mật khẩu thô từ HR
}