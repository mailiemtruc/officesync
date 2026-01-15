package com.officesync.chat_service.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Configuration
@EnableWebSocketMessageBroker
@RequiredArgsConstructor
@Slf4j
@Order(Ordered.HIGHEST_PRECEDENCE + 99)
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final JwtDecoder jwtDecoder; // Inject JwtDecoder từ SecurityConfig sang

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/ws").setAllowedOriginPatterns("*");
        registry.addEndpoint("/ws").setAllowedOriginPatterns("*").withSockJS();
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.setApplicationDestinationPrefixes("/app");
        registry.enableSimpleBroker("/topic", "/queue", "/user");
        registry.setUserDestinationPrefix("/user");
    }

    // 👇 ĐÂY LÀ PHẦN QUAN TRỌNG NHẤT BẠN ĐANG THIẾU 👇
    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                
                // Chỉ kiểm tra khi Client gửi lệnh CONNECT
                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    
                    // 1. Lấy Token từ header "Authorization"
                    String authHeader = accessor.getFirstNativeHeader("Authorization");
                    
                    if (authHeader != null && authHeader.startsWith("Bearer ")) {
                        String token = authHeader.substring(7);
                        try {
                            // 2. Giải mã Token (Sẽ dùng Secret Key bên SecurityConfig để check)
                            Jwt jwt = jwtDecoder.decode(token);
                            
                            // 3. Lấy thông tin user (Email nằm trong subject hoặc claim)
                            String email = jwt.getSubject(); // Lấy email từ "sub"
                            
                            // 4. Tạo đối tượng Authentication của Spring Security
                            // (Bạn có thể map role từ jwt claims nếu cần, ở đây mình để list rỗng cho đơn giản)
                            Authentication auth = new UsernamePasswordAuthenticationToken(
                                    email, 
                                    null, 
                                    Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER"))
                            );
                            
                            // 5. Gán User vào phiên làm việc của Socket
                            accessor.setUser(auth);
                            
                            log.info("✅ Socket Auth Success: {}", email);
                            
                        } catch (Exception e) {
                            log.error("❌ Socket Auth Failed: {}", e.getMessage());
                        }
                    } else {
                        log.warn("⚠️ Socket Connect without Token!");
                    }
                }
                return message;
            }
        });
    }
}