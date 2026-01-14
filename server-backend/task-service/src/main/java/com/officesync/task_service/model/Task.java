// com.officesync.task_service.model.Task.java
package com.officesync.task_service.model;

import java.time.LocalDateTime;

import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "tasks")
@Data
public class Task {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    private TaskStatus status; // TODO, IN_PROGRESS, REVIEW, DONE

    @Enumerated(EnumType.STRING)
    private TaskPriority priority; // LOW, MEDIUM, HIGH

    private LocalDateTime createdAt;
    private LocalDateTime dueDate;

    @Column(name = "creator_id")
    private Long creatorId;

    @Column(name = "assignee_id")
    private Long assigneeId;
    
    private String creatorName;
    private String assigneeName;
    
    private String departmentName;
    private Long departmentId;
    private Long companyId;

    @Column(name = "is_published")
    @com.fasterxml.jackson.annotation.JsonProperty("isPublished")
    private boolean published = false; // Đổi tên thành published để Lombok tạo hàm setPublished()
}
