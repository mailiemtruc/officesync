package com.officesync.chat_service.service;

import com.officesync.chat_service.dto.ChatMessageDTO;
import com.officesync.chat_service.model.ChatMessage;
import com.officesync.chat_service.repository.ChatMessageRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Date;
import java.util.List;

@Service
@RequiredArgsConstructor // Tự động tạo Constructor cho Repository
public class ChatService {

    private final ChatMessageRepository repository;

    // Hàm này phục vụ cho ChatController khi nhận từ WebSocket
    public ChatMessage saveMessage(ChatMessageDTO dto) {
        ChatMessage message = new ChatMessage();
        
        // Map dữ liệu từ DTO sang Entity
        message.setContent(dto.getContent());
        message.setTimestamp(new Date());
        
        // --- XỬ LÝ TẠM ĐỂ TEST ---
        // Vì DB yêu cầu Long ID, nhưng bản test gửi String tên.
        // Ta set cứng ID để test chạy được đã (Sau này login thật sẽ sửa sau)
        message.setSenderId(1L);     // Giả bộ người gửi là ID 1
        message.setRecipientId(2L);  // Giả bộ người nhận là ID 2
        message.setChatId("1_2");    // Phòng chat ảo
        // --------------------------

        return repository.save(message);
    }

    // Hàm cũ (giữ lại nếu cần dùng cho Logic khác sau này)
    public ChatMessage saveMessage(Long senderId, Long recipientId, String content) {
        String chatId = (senderId < recipientId) ? senderId + "_" + recipientId : recipientId + "_" + senderId;
        ChatMessage message = ChatMessage.builder()
                .chatId(chatId)
                .senderId(senderId)
                .recipientId(recipientId)
                .content(content)
                .timestamp(new Date())
                .build();
        return repository.save(message);
    }
    public List<ChatMessage> getChatHistory(Long senderId, Long recipientId) {
        // Logic tạo ChatID giống hệt lúc lưu (nhỏ đứng trước, lớn đứng sau)
        // Ví dụ: User 1 và User 2 nhắn nhau thì chatId luôn là "1_2"
        String chatId = (senderId < recipientId) ? senderId + "_" + recipientId : recipientId + "_" + senderId;
        
        return repository.findByChatId(chatId);
    }
}