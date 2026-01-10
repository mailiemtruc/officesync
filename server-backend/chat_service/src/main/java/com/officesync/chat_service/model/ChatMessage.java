package com.officesync.chat_service.model;

import jakarta.persistence.*;
import lombok.*;
import java.util.Date;

@Entity
@Table(name = "chat_messages")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ChatMessage {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String chatId;
    private Long senderId;
    private Long recipientId;
    
    @Column(columnDefinition = "TEXT")
    private String content;
    
    private Date timestamp;

    @Enumerated(EnumType.STRING)
    private MessageType type; // Thêm trường này

    // --- THÊM ĐOẠN NÀY ĐỂ HẾT LỖI ĐỎ ---
    public enum MessageType {
        CHAT,
        JOIN,
        LEAVE
    }
}