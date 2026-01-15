package com.officesync.chat_service.repository;

import com.officesync.chat_service.model.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    // 1. Lấy lịch sử chat của 1 cuộc hội thoại (Sắp xếp cũ nhất -> mới nhất)
    List<ChatMessage> findByChatIdOrderByTimestampAsc(String chatId);
    List<ChatMessage> findByRoomIdOrderByTimestampAsc(Long roomId);

    // 2. [QUAN TRỌNG] Query lấy danh sách tin nhắn mới nhất của từng người (Sidebar)
    // Logic: Tìm tin nhắn có Max Timestamp của từng cặp đôi liên quan đến User
    @Query(value = """
        SELECT m.* FROM chat_messages m
        INNER JOIN (
            SELECT 
                CASE 
                    WHEN sender_id = :userId THEN recipient_id 
                    ELSE sender_id 
                END AS partner_id,
                MAX(timestamp) as max_time
            FROM chat_messages
            WHERE sender_id = :userId OR recipient_id = :userId
            GROUP BY partner_id
        ) latest ON (
            (m.sender_id = :userId AND m.recipient_id = latest.partner_id) 
            OR (m.recipient_id = :userId AND m.sender_id = latest.partner_id)
        ) AND m.timestamp = latest.max_time
        ORDER BY m.timestamp DESC
    """, nativeQuery = true)
    List<ChatMessage> findRecentConversations(@Param("userId") Long userId);
}