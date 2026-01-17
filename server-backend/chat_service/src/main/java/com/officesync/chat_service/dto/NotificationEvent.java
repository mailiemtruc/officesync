package com.officesync.chat_service.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class NotificationEvent {
    private Long userId;        // Recipient ID (User who is currently Offline)
    private String title;       // Title (Sender Name or Group Name)
    private String body;        // Message Content
    private String type;        // "CHAT"
    private Long referenceId;   // RoomId (To navigate correctly when clicking notification)
}