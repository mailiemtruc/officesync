package com.officesync.chat_service.listener;

import com.fasterxml.jackson.databind.ObjectMapper; // [MỚI] Import này
import com.officesync.chat_service.config.RabbitMQConfig;
import com.officesync.chat_service.dto.UserCreatedEvent;
import com.officesync.chat_service.model.ChatUser;
import com.officesync.chat_service.repository.ChatUserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.Date;

@Slf4j
@Component
@RequiredArgsConstructor
public class UserSyncListener {

    private final ChatUserRepository chatUserRepo;
    private final ObjectMapper objectMapper; // [MỚI] Inject ObjectMapper để giải mã JSON

    // Hứng sự kiện tạo User từ Core
    @RabbitListener(queues = RabbitMQConfig.QUEUE_CHAT_USER_SYNC)
    public void syncUser(String message) { // [QUAN TRỌNG] Đổi tham số từ UserCreatedEvent -> String
        try {
            log.info("📥 [Chat Service] Raw Message: {}", message);

            // [QUAN TRỌNG] Tự tay giải mã JSON String thành Object
            UserCreatedEvent event = objectMapper.readValue(message, UserCreatedEvent.class);

            log.info("--> Parsed User: {} ({})", event.getFullName(), event.getEmail());

            // Logic lưu vào DB giữ nguyên
            ChatUser user = new ChatUser();
            user.setId(event.getId()); 
            user.setEmail(event.getEmail());
            user.setFullName(event.getFullName());
            user.setLastActiveAt(java.time.LocalDateTime.now());
            user.setCompanyId(event.getCompanyId());
            
            // Set mặc định online = false
            user.setOnline(false);

            chatUserRepo.save(user);
            log.info("✅ Đã lưu User vào Chat DB thành công!");

        } catch (Exception e) {
            log.error("❌ Lỗi đồng bộ User (JSON Parse Error): ", e);
        }
    }
}