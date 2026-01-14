package com.officesync.task_service.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class DepartmentSyncEvent {
    private Long id;
    private String name;
    private Long companyId;
    private Long managerId;
    private String description;
    private String departmentCode;
}