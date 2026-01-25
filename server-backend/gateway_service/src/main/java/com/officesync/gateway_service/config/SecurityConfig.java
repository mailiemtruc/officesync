package com.officesync.gateway_service.config;

import java.nio.charset.StandardCharsets;

import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import static org.springframework.security.config.Customizer.withDefaults;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm; // 👈 Nhớ import cái này
import org.springframework.security.oauth2.jwt.NimbusReactiveJwtDecoder;
import org.springframework.security.oauth2.jwt.ReactiveJwtDecoder; // 👈 Nhớ import cái này
import org.springframework.security.web.server.SecurityWebFilterChain;

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
                .pathMatchers("/api/files/**").authenticated()
                .pathMatchers("/v3/api-docs/**", "/swagger-ui/**", "/*/v3/api-docs/**").permitAll()
                .pathMatchers("/img/**").permitAll()
                // 2. Mở cửa cho WebSocket
                .pathMatchers("/ws-**", "/ws/**").permitAll()
                .pathMatchers("/api/notifications/register-device").permitAll()
                .pathMatchers("/api/notifications/**").permitAll()
                // 3. Các request khác bắt buộc phải có Token hợp lệ
                .anyExchange().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(withDefaults()));

        return http.build();
    }

    // ✅ ĐÃ SỬA: Đồng bộ Encoding và Thuật toán với Core Service
    @Bean
    public ReactiveJwtDecoder jwtDecoder() {
        // 1. Dùng UTF_8 để đồng bộ với Core Service
        byte[] keyBytes = jwtSecret.getBytes(StandardCharsets.UTF_8);
        
        // 2. Tạo SecretKeySpec
        SecretKeySpec spec = new SecretKeySpec(keyBytes, "HmacSHA512");
        
        // 3. Cấu hình Decoder đúng chuẩn WebFlux
        return NimbusReactiveJwtDecoder.withSecretKey(spec)
                .macAlgorithm(MacAlgorithm.HS512) // Chỉ định thuật toán 512
                .build();
    }
}