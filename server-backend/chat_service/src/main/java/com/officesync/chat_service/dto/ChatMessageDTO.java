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
    // Nó sẽ hết báo đỏ khi bạn sửa xong file ChatMessage.java ở bước 2
    private ChatMessage.MessageType type; 
    private String timestamp;
}