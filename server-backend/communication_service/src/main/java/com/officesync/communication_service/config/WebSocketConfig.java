package com.officesync.communication_service.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // 1. Prefix cho các kênh mà Client sẽ đăng ký lắng nghe (Subscribe)
        // Ví dụ: /topic/company/1, /topic/post/100
        config.enableSimpleBroker("/topic");
        
        // 2. Prefix cho các lệnh Client gửi lên (nếu có, bài này mình chưa dùng nhiều)
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // 3. Endpoint để bắt tay (Handshake) kết nối WebSocket
        // App Flutter sẽ gọi vào: ws://localhost:8088/ws
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*") // Cho phép mọi nguồn (Flutter, Web...) kết nối
                .withSockJS(); // Hỗ trợ fallback nếu mạng chặn WebSocket (tùy chọn)
        
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*"); // Cấu hình thêm cái này cho chắc ăn với Client thuần
    }
}