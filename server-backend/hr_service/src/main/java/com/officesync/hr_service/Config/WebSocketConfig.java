package com.officesync.hr_service.Config;

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
        // Client sẽ lắng nghe các url bắt đầu bằng /topic
        config.enableSimpleBroker("/topic");
        // Client sẽ gửi tin nhắn lên server qua prefix /app (nếu cần)
        config.setApplicationDestinationPrefixes("/app");
    }

   @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // [QUAN TRỌNG] Chỉ giữ lại dòng này.
        // URL kết nối từ Flutter sẽ là: ws://IP:8081/ws-hr
        // Đã bỏ .withSockJS()
        registry.addEndpoint("/ws-hr")
                .setAllowedOriginPatterns("*");
    }
}