package com.officesync.communication_service.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Builder
public class NotificationEvent {
    private Long userId;        // Gửi cho ai
    private String title;       // Tiêu đề
    private String body;        // Nội dung
    private String type;        // Loại: "ANNOUNCEMENT", "COMMENT", "REACTION"
    private Long referenceId;   // ID bài viết
}