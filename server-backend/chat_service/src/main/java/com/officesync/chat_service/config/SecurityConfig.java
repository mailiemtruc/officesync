package com.officesync.chat_service.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/ws/**").permitAll()  // Cho phép bắt tay WebSocket
                .requestMatchers("/api/**").permitAll() // API lấy lịch sử (có thể thêm Filter check Token sau)
                .anyRequest().authenticated()
            );
        return http.build();
    }
}