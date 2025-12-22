package com.officesync.hr_service.Model;

import java.util.List;

import org.hibernate.annotations.Formula; // [QUAN TRỌNG] Import Formula

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties; // [IMPORT QUAN TRỌNG]

import jakarta.persistence.Column; // [IMPORT QUAN TRỌNG]
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Entity
@Table(name = "departments")
@Data
@EqualsAndHashCode(callSuper = true)
public class Department extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String name; 

 @Column(name = "department_code", length = 20, unique = true, updatable = false)
    private String departmentCode;
    @Column(name = "color", length = 10)
    private String color;
    @Column(columnDefinition = "TEXT")
    private String description;
// [MỚI] Tự động đếm số nhân viên bằng câu lệnh SQL con (Sub-query)
    // Lưu ý: 'employees' là tên bảng trong DB, 'department_id' là khóa ngoại
    @Formula("(SELECT count(*) FROM employees e WHERE e.department_id = id)")
    private int memberCount;
    @OneToOne
    @JoinColumn(name = "manager_id")
    @JsonIgnoreProperties({"department", "hibernateLazyInitializer", "handler"})
    private Employee manager;

    @OneToMany(mappedBy = "department", fetch = FetchType.LAZY)
    @JsonIgnore
    private List<Employee> employees;
}