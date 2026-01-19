package com.officesync.task_service.config;

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
        // Topic để App Mobile lắng nghe (Subscription)
        config.enableSimpleBroker("/topic");
        // Prefix cho các tin nhắn gửi từ App lên Server (nếu cần)
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Endpoint để Flutter kết nối: ws://localhost:8086/ws-task
        registry.addEndpoint("/ws-task").setAllowedOriginPatterns("*").withSockJS();
        registry.addEndpoint("/ws-task").setAllowedOriginPatterns("*");
    }
}