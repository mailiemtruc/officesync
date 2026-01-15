package com.officesync.chat_service.dto;

import lombok.Data;
import java.util.List;

@Data
public class CreateGroupRequest {
    private String groupName;
    private List<Long> memberIds; // Danh sách ID nhân viên muốn thêm vào nhóm
}