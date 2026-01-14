package com.officesync.task_service.model;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "task_users")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TaskUser {

    @Id
    private Long id; // id do HR/Core cung cấp, không auto-gen here

    private String fullName;

    private String email;

    private Long companyId;

    private String role;

    private String status;

    private Long departmentId;
}