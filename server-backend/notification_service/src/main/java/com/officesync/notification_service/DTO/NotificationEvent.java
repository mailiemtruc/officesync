package com.officesync.notification_service.DTO;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class NotificationEvent {
    private Long userId;        // Gửi cho ai
    private String title;       // Tiêu đề
    private String body;        // Nội dung
    private String type;        // Loại: "REQUEST", "ANNOUNCEMENT"
    private Long referenceId;   // ID của đơn (để click vào mở ra)
}