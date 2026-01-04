package com.officesync.hr_service.Model;

import java.time.LocalDate;

import com.fasterxml.jackson.annotation.JsonFormat;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;
@Entity
@Table(name = "employees")
@Data
@EqualsAndHashCode(callSuper = true)
public class Employee extends BaseEntity {

    @Id
    @Column(name = "user_id")
    private Long id; 

    @Column(name = "employee_code", length = 20, unique = true, updatable = false)
    private String employeeCode; 

    @Column(name = "full_name", nullable = false)
    private String fullName; 

    @Column(nullable = false)
    private String email;

    @Column(length = 15)
    private String phone;

   @Column(name = "date_of_birth") 
   @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate dateOfBirth;

    @Column(name = "avatar_url")
    private String avatarUrl; 

    @Enumerated(EnumType.STRING)
    private EmployeeStatus status; 

    @ManyToOne
    @JoinColumn(name = "department_id")
    @EqualsAndHashCode.Exclude // [QUAN TRỌNG] Ngắt vòng lặp hashCode
    @ToString.Exclude          // [QUAN TRỌNG] Ngắt vòng lặp toString
    private Department department;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false)
    private EmployeeRole role;

    // [MỚI] THÊM HÀM NÀY ĐỂ JSON TRẢ VỀ CÓ TÊN PHÒNG BAN
    public String getDepartmentName() {
        return department != null ? department.getName() : null;
    }
}