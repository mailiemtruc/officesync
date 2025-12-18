package com.officesync.communication_service.security;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Component;
import java.nio.charset.StandardCharsets;
import java.security.Key;

@Component
public class JwtTokenProvider {

    // 🔴 BẮT BUỘC GIỐNG HỆT BÊN CORE SERVICE
    private final String JWT_SECRET = "OfficeSync_Super_Secure_Secret_Key_For_Enterprise_Level_Security_Version_2025_Longer_Is_Better";

    private Key getSigningKey() {
        byte[] keyBytes = JWT_SECRET.getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    public String getEmailFromToken(String token) {
        return Jwts.parserBuilder().setSigningKey(getSigningKey()).build()
                .parseClaimsJws(token).getBody().getSubject();
    }

    public boolean validateToken(String authToken) {
        try {
            Jwts.parserBuilder().setSigningKey(getSigningKey()).build().parseClaimsJws(authToken);
            return true;
        } catch (Exception ex) {
            System.err.println("Token không hợp lệ: " + ex.getMessage());
        }
        return false;
    }
}