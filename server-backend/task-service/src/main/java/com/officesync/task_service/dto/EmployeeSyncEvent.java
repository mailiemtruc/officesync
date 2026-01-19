package com.officesync.task_service.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.time.LocalDate;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class EmployeeSyncEvent {
    private Long id;
    private String email;
    private String fullName;
    private Long companyId;
    private String role;
    private String status;
    private Long departmentId;
}
