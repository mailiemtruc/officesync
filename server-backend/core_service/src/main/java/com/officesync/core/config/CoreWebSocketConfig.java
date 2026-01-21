package com.officesync.core.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker
public class CoreWebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        config.enableSimpleBroker("/topic");
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // [QUAN TRỌNG] Chỉ giữ lại 1 dòng này thôi.
        // - Bỏ .withSockJS() -> Để dùng Raw WebSocket (Flutter mới hiểu được)
        // - URL kết nối từ Flutter sẽ là: ws://IP:8080/ws-core
        registry.addEndpoint("/ws-core")
                .setAllowedOriginPatterns("*"); 
    }
}