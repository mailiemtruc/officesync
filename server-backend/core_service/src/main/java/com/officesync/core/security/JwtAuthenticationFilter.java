package com.officesync.core.security;

import java.io.IOException;
import java.util.Collections;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.officesync.core.model.User;
import com.officesync.core.repository.UserRepository;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Autowired
    private JwtTokenProvider tokenProvider;
    @Autowired
    private UserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        try {
            String jwt = getJwtFromRequest(request);

            if (jwt != null && tokenProvider.validateToken(jwt)) {
                String email = tokenProvider.getEmailFromToken(jwt);
                
                // 🔴 [MỚI] Lấy version từ Token gửi lên
                String tokenVersion = tokenProvider.getVersionFromToken(jwt);

                // Lấy user từ DB
                User user = userRepository.findByEmail(email).orElse(null);
                
                if (user != null) {
                    // 🔴 [MỚI] LOGIC SO SÁNH VERSION (HARD KICK)
                    // Lấy version hiện tại đang lưu trong DB
                    String currentVersionInDb = user.getTokenVersion();
                    
                    // Logic kiểm tra:
                    // 1. Nếu DB chưa có version (null) -> Chấp nhận (Hỗ trợ giai đoạn đầu chuyển đổi)
                    // 2. Nếu DB có version -> Bắt buộc Token phải có version khớp y hệt
                    boolean isValidVersion = currentVersionInDb == null || currentVersionInDb.equals(tokenVersion);

                    if (isValidVersion) {
                        // Version khớp -> Cho phép xác thực
                        UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                                user, null, Collections.singletonList(new SimpleGrantedAuthority(user.getRole())));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    } else {
                        // Version lệch -> Token này là của thiết bị cũ -> CHẶN
                        System.out.println("❌ Blocked old token for user: " + email + ". Token Ver: " + tokenVersion + " | DB Ver: " + currentVersionInDb);
                        // Khi không setAuthentication, Spring Security sẽ tự động trả về 401 hoặc 403 ở các filter sau.
                    }
                }
            }
        } catch (Exception ex) {
            System.out.println("Could not set user authentication in security context: " + ex.getMessage());
        }
        
        filterChain.doFilter(request, response);
    }

    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}