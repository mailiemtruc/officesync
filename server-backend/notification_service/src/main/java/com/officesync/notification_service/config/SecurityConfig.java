package com.officesync.notification_service.config;

import com.officesync.notification_service.security.JwtAuthenticationFilter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable()) // Tắt CSRF vì dùng Token
            .authorizeHttpRequests(auth -> auth
                // 1. Cho phép API đăng ký thiết bị không cần login (nếu muốn)
                .requestMatchers("/api/notifications/register-device").permitAll()
                // 2. Cho phép API test
                .requestMatchers("/api/notifications/test-send").permitAll() 
                // 3. Các API lấy danh sách thông báo phải có Token
                .requestMatchers("/api/notifications/user/**").authenticated()
                // 4. Các API khác bắt buộc login
                .anyRequest().authenticated()
            )
            .sessionManagement(sess -> sess.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}