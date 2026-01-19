package com.officesync.chat_service.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class DepartmentEventDTO {
    private String event;       
    private Long deptId;        
    private String deptName;    
    private Long managerId;     
    private List<Long> memberIds; 
    private Long companyId; // [QUAN TRỌNG]
}