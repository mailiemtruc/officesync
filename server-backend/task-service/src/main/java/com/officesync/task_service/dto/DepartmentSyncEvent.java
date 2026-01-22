package com.officesync.task_service.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DepartmentSyncEvent {
    private String event;
    private Long deptId;
    private String deptName; 
    private Long managerId;
    private Long companyId;
    private List<Long> memberIds;
    private String departmentCode; 
    private String description;
}