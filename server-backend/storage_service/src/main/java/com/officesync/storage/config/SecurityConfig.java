package com.officesync.storage.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable()) // Tắt CSRF để cho phép upload file qua API
            .authorizeHttpRequests(auth -> auth
                .anyRequest().permitAll() // Cho phép mọi request (Upload/Xem ảnh)
            );
        return http.build();
    }
}