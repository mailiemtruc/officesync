package com.officesync.gateway_service.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.oauth2.jwt.NimbusReactiveJwtDecoder;
import org.springframework.security.oauth2.jwt.ReactiveJwtDecoder;
import org.springframework.security.web.server.SecurityWebFilterChain;

import javax.crypto.spec.SecretKeySpec;

import static org.springframework.security.config.Customizer.withDefaults;

@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Bean
    public SecurityWebFilterChain springSecurityFilterChain(ServerHttpSecurity http) {
        http
            .csrf(ServerHttpSecurity.CsrfSpec::disable)
            .authorizeExchange(exchanges -> exchanges
                // 1. Mở cửa API Auth và Swagger công khai
                .pathMatchers("/api/auth/**").permitAll()
                .pathMatchers("/v3/api-docs/**", "/swagger-ui/**", "/*/v3/api-docs/**").permitAll()
                
                // 2. Mở cửa cho WebSocket
                .pathMatchers("/ws-**", "/ws/**").permitAll()
                
                // 3. Các request khác bắt buộc phải có Token hợp lệ
                .anyExchange().authenticated()
            )
            // Cấu hình Gateway thành Resource Server để kiểm tra JWT
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(withDefaults()));

        return http.build();
    }

    // ✅ THÊM BEAN NÀY: Để Gateway tự giải mã JWT bằng Secret Key thủ công
    @Bean
    public ReactiveJwtDecoder jwtDecoder() {
        byte[] keyBytes = jwtSecret.getBytes();
        SecretKeySpec spec = new SecretKeySpec(keyBytes, "HmacSHA256");
        return NimbusReactiveJwtDecoder.withSecretKey(spec).build();
    }
}