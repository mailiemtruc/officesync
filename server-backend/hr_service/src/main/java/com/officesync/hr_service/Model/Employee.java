package com.officesync.hr_service.Model;

import java.time.LocalDate;

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
    private LocalDate dateOfBirth;

    @Column(name = "avatar_url")
    private String avatarUrl; 

    @Enumerated(EnumType.STRING)
    private EmployeeStatus status; 

    @ManyToOne
    @JoinColumn(name = "department_id")
    private Department department;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false)
    private EmployeeRole role;
}