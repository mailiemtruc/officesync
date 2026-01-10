package com.officesync.chat_service.config;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.Key;

@Component
public class JwtTokenProvider {

    // COPY CHÍNH XÁC KEY TỪ CORE SERVICE
    private final String JWT_SECRET = "OfficeSync_Super_Secure_Secret_Key_For_Enterprise_Level_Security_Version_2025_Longer_Is_Better";

    private Key getSigningKey() {
        byte[] keyBytes = JWT_SECRET.getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    // Lấy Email từ Token để định danh (nếu cần)
    public String getEmailFromToken(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();
        return claims.getSubject();
    }

    // Kiểm tra Token hợp lệ
    public boolean validateToken(String authToken) {
        try {
            Jwts.parserBuilder().setSigningKey(getSigningKey()).build().parseClaimsJws(authToken);
            return true;
        } catch (Exception ex) {
            return false;
        }
    }
}