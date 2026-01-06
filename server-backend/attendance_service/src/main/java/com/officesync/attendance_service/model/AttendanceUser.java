package com.officesync.attendance_service.model;

import java.time.LocalDate;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "attendance_users") // Bảng phụ lưu info user
@Data
public class AttendanceUser {
    @Id
    private Long id; // User ID (Đồng bộ với HR)
    private String fullName;
    private String email;
    private String phone;
    private LocalDate dateOfBirth;
    private Long companyId;
    private String role;           
    private String departmentName;
}