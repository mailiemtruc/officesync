package com.officesync.chat_service.repository;

import com.officesync.chat_service.model.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    // Lấy tin nhắn theo chatId (vd: "10_15")
    List<ChatMessage> findByChatId(String chatId);
}