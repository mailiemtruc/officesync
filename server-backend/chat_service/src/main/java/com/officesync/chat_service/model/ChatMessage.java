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

    // [MỚI] Quan trọng nhất: Tin nhắn thuộc về Phòng nào
    @Column(name = "room_id")
    private Long roomId;

    // Vẫn giữ lại để tương thích code cũ (nhưng sau này sẽ ít dùng)
    private String chatId; 

    private Long senderId;
    
    // Chat 1-1 thì có recipientId, Chat Group thì field này có thể NULL
    private Long recipientId; 
    
    @Column(columnDefinition = "TEXT")
    private String content;
    
    private Date timestamp;

    @Enumerated(EnumType.STRING)
    private MessageType type; 

    public enum MessageType {
        CHAT,   // Tin nhắn văn bản
        JOIN,   // Tham gia phòng
        LEAVE,  // Rời phòng
        IMAGE,  // [MỚI] Tin nhắn hình ảnh
        FILE    // [MỚI] Tin nhắn tệp tin
    }
    @Transient
    private String senderName;
    @Transient
    private String avatarUrl;
}