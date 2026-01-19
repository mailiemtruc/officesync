package com.officesync.task_service.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class NotificationEvent {
    private Long userId;        // Người nhận (Manager hoặc Staff)
    private String title;
    private String body;
    private String type;        // Loại: "TASK_ASSIGNED"
    private Long referenceId;   // ID của Task
}