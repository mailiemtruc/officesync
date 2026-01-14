package com.officesync.hr_service.Model;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
 
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.ToString;
@Entity
@Table(name = "departments", indexes = {
    @Index(name = "idx_dept_name", columnList = "name"),
    @Index(name = "idx_dept_company", columnList = "company_id"),
    @Index(name = "idx_dept_code", columnList = "department_code")
})
@Data
@EqualsAndHashCode(callSuper = true)
@JsonIgnoreProperties(value = {"hibernateLazyInitializer", "handler"}, ignoreUnknown = true)
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
  
// THAY BẰNG:
@Transient
private long memberCount = 0;

    @Column(name = "is_hr", nullable = false)
    private Boolean isHr = false; 

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_id")
    @JsonIgnoreProperties({"department", "hibernateLazyInitializer", "handler"})
    private Employee manager;

    @OneToMany(mappedBy = "department", fetch = FetchType.LAZY)
    @JsonIgnore
    @EqualsAndHashCode.Exclude // [QUAN TRỌNG]
    @ToString.Exclude          // [QUAN TRỌNG]
    private List<Employee> employees;
}