package com.officesync.hr_service.DTO;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class DepartmentSyncEvent {
    
    public static final String ACTION_CREATE = "DEPT_CREATED";
    public static final String ACTION_DELETE = "DEPT_DELETED";
    public static final String ACTION_ADD_MEMBER = "MEMBER_ADDED";
    public static final String ACTION_REMOVE_MEMBER = "MEMBER_REMOVED";

    private String event;
    private Long deptId;
    private String deptName;
    private Long managerId;
    private List<Long> memberIds;
    private Long companyId;
}