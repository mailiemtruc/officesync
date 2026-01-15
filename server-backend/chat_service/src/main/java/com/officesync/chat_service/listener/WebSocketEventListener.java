package com.officesync.chat_service.listener;

import com.officesync.chat_service.model.ChatUser;
import com.officesync.chat_service.repository.ChatUserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessagingTemplate; // [QUAN TRỌNG] Phải import cái này
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.time.LocalDateTime;
import java.util.Optional;

@Component
@Slf4j
@RequiredArgsConstructor
public class WebSocketEventListener {

    private final ChatUserRepository chatUserRepository;
    // [QUAN TRỌNG] Inject công cụ gửi tin nhắn
    private final SimpMessagingTemplate messagingTemplate; 

    // 1. Khi User KẾT NỐI (Mở App) -> Bật Online
    @EventListener
    public void handleWebSocketConnectListener(SessionConnectedEvent event) {
        StompHeaderAccessor headerAccessor = StompHeaderAccessor.wrap(event.getMessage());
        if(headerAccessor.getUser() != null) {
            String email = headerAccessor.getUser().getName(); // Lấy email từ Token
            log.info("🟢 User Connected: {}", email);
            updateStatus(email, true);
        }
    }

    // 2. Khi User NGẮT KẾT NỐI (Tắt App/Rớt mạng) -> Tắt Online
    @EventListener
    public void handleWebSocketDisconnectListener(SessionDisconnectEvent event) {
        StompHeaderAccessor headerAccessor = StompHeaderAccessor.wrap(event.getMessage());
        if(headerAccessor.getUser() != null) {
            String email = headerAccessor.getUser().getName();
            log.info("🔴 User Disconnected: {}", email);
            updateStatus(email, false);
        }
    }

    // Hàm cập nhật vào Database và Bắn thông báo
    private void updateStatus(String email, boolean isOnline) {
        Optional<ChatUser> userOpt = chatUserRepository.findByEmail(email);
        if (userOpt.isPresent()) {
            ChatUser user = userOpt.get();
            
            // 1. Update DB
            user.setOnline(isOnline);
            user.setLastActiveAt(LocalDateTime.now());
            chatUserRepository.save(user);

            // 2. [QUAN TRỌNG] Bắn tin cho mọi người biết trạng thái mới
            // Client Flutter sẽ lắng nghe ở "/topic/status"
            log.info("📢 Bắn event Status: {} -> {}", user.getFullName(), isOnline);
            messagingTemplate.convertAndSend("/topic/status", user);
        }
    }
}