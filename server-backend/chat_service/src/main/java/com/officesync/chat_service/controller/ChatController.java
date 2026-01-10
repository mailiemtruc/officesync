package com.officesync.chat_service.controller;

import com.officesync.chat_service.dto.ChatMessageDTO;
import com.officesync.chat_service.model.ChatMessage;
import com.officesync.chat_service.service.ChatService;
import lombok.RequiredArgsConstructor;

import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

import java.util.Date;
import java.util.List;
@Controller
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;
    private final SimpMessagingTemplate messagingTemplate;

    @MessageMapping("/chat.sendMessage")
    public void sendMessage(@Payload ChatMessageDTO chatMessageDTO) {
        
        // 1. Lưu xuống DB (Vẫn dùng ID cứng 1 và 2 trong Service để test)
        ChatMessage savedMsg = chatService.saveMessage(chatMessageDTO);
        
        System.out.println("--> [Server] Đã lưu DB. Đang gửi từ User " + savedMsg.getSenderId() + " tới User " + savedMsg.getRecipientId());

        // 2. Tạo gói tin trả về
        ChatMessageDTO response = new ChatMessageDTO(
            savedMsg.getContent(),
            String.valueOf(savedMsg.getSenderId()),
            savedMsg.getType(),
            savedMsg.getTimestamp().toString()
        );

        // 3. CÁCH FIX: Gửi thẳng vào kênh riêng của từng người bằng convertAndSend
        
        // Gửi cho NGƯỜI NHẬN (User 2 nghe tại /topic/user/2)
        messagingTemplate.convertAndSend(
            "/topic/user/" + savedMsg.getRecipientId(), 
            response
        );

        // Gửi cho NGƯỜI GỬI (User 1 nghe tại /topic/user/1 - để tự thấy tin mình vừa nhắn)
        messagingTemplate.convertAndSend(
            "/topic/user/" + savedMsg.getSenderId(), 
            response
        );
    }
    @GetMapping("/api/messages/{senderId}/{recipientId}")
    public ResponseEntity<List<ChatMessage>> getChatHistory(
            @PathVariable Long senderId,
            @PathVariable Long recipientId) {
        
        return ResponseEntity.ok(chatService.getChatHistory(senderId, recipientId));
    }
}