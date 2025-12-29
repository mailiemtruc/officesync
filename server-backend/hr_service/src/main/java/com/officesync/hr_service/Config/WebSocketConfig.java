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
        // Flutter sẽ connect vào đường dẫn: ws://IP:8081/ws-hr
        registry.addEndpoint("/ws-hr").setAllowedOriginPatterns("*").withSockJS();
        registry.addEndpoint("/ws-hr").setAllowedOriginPatterns("*");
    }
}