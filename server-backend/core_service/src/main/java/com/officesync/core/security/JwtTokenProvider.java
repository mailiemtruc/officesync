package com.officesync.core.security;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

import org.springframework.stereotype.Component;

import com.officesync.core.model.User;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.UnsupportedJwtException;
import io.jsonwebtoken.security.Keys;

@Component
public class JwtTokenProvider {
    
    // Chuỗi bí mật (Giữ nguyên của bạn)
    private final String JWT_SECRET = "OfficeSync_Super_Secure_Secret_Key_For_Enterprise_Level_Security_Version_2025_Longer_Is_Better";
    
    private final long JWT_EXPIRATION = 604800000L; // 7 ngày

    private Key getSigningKey() {
        byte[] keyBytes = JWT_SECRET.getBytes(StandardCharsets.UTF_8);
        return Keys.hmacShaKeyFor(keyBytes);
    }

    // 🔴 [SỬA 1] Thêm tham số tokenVersion vào hàm tạo Token
    public String generateToken(User user, String tokenVersion) {
        return Jwts.builder()
                .setSubject(user.getEmail()) 
                .claim("role", user.getRole())
                
                // 👇 Lưu version vào payload của Token
                .claim("version", tokenVersion) 
                
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + JWT_EXPIRATION))
                .signWith(getSigningKey(), SignatureAlgorithm.HS512)
                .compact();
    }

    // Lấy Email từ Token (Giữ nguyên)
    public String getEmailFromToken(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody()
                .getSubject();
    }

    // 🔴 [SỬA 2] Thêm hàm lấy Version từ Token
    public String getVersionFromToken(String token) {
        return Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody()
                .get("version", String.class); // Lấy field 'version' dạng String
    }

    // Validate Token (Giữ nguyên)
    public boolean validateToken(String authToken) {
        try {
            Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(authToken);
            return true;
        } catch (MalformedJwtException ex) {
            System.err.println("Invalid JWT token");
        } catch (ExpiredJwtException ex) {
            System.err.println("Expired JWT token");
        } catch (UnsupportedJwtException ex) {
            System.err.println("Unsupported JWT token");
        } catch (IllegalArgumentException ex) {
            System.err.println("JWT claims string is empty.");
        }
        return false;
    }
}