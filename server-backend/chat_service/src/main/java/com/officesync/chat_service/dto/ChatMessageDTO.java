package com.officesync.chat_service.dto;

import com.officesync.chat_service.model.ChatMessage;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatMessageDTO {
    private String content;
    private String sender;
    
    // [CŨ] Dùng cho chat 1-1 (Vẫn giữ để tương thích nếu cần)
    private String recipientId; 

    // [MỚI - QUAN TRỌNG] ID phòng chat (Dùng cho cả 1-1 và Group)
    // Nếu Frontend gửi roomId -> Gửi vào nhóm.
    // Nếu Frontend không gửi roomId mà gửi recipientId -> Backend tự tìm phòng 1-1.
    private Long roomId; 

    private ChatMessage.MessageType type; 
    private String timestamp;
    
}