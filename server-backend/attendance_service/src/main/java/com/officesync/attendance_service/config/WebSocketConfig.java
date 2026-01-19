package com.officesync.attendance_service.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

@Configuration
@EnableWebSocketMessageBroker // <--- Annotation này sẽ tạo ra SimpMessagingTemplate
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    @Override
    public void configureMessageBroker(MessageBrokerRegistry config) {
        // Kích hoạt broker bộ nhớ trong (Simple Broker)
        // Các topic bắt đầu bằng /topic sẽ được gửi về Client
        config.enableSimpleBroker("/topic");

        // Tiền tố cho các message từ Client gửi lên Server (nếu có dùng)
        config.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Đăng ký endpoint '/ws' để Mobile App kết nối vào
        // URL kết nối sẽ là: ws://10.0.2.2:8083/ws
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*"); // Quan trọng: Cho phép mọi nguồn kết nối (CORS)
        
        // (Tùy chọn) Thêm endpoint hỗ trợ SockJS nếu cần cho Web
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }
}