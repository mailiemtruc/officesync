package com.officesync.attendance_service.dto;

import java.time.LocalDate;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class EmployeeSyncEvent {
    private Long id; // [MỚI] Thêm trường này để đồng bộ Update/Delete
    private String email;
    private String fullName;
    private String phone;
    private LocalDate dateOfBirth;
    private Long companyId;
    private String role;
    private String status;
    private String password; // [MỚI] Khôi phục lại trường này
    private String departmentName;
}