package com.officesync.task_service.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "task_departments")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskDepartment {

    @Id
    private Long id; // id từ HR/Core

    private String name;

    private Long companyId;

    private Long managerId;

    private String description;

    private String departmentCode;
}