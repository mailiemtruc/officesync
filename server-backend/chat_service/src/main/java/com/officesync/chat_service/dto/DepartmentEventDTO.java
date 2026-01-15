package com.officesync.chat_service.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class DepartmentEventDTO {
    private String event;       // Loại sự kiện: "DEPT_CREATED"
    private Long deptId;        // ID phòng ban
    private String deptName;    // Tên phòng ban
    private Long managerId;     // ID trưởng phòng (lấy từ mục "Select Manager")
    private List<Long> memberIds; // Danh sách nhân viên ban đầu
}