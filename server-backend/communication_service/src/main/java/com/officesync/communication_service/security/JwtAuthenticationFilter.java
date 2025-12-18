package com.officesync.communication_service.security;

import com.officesync.communication_service.model.User; // Đảm bảo bạn đã copy class User hoặc import đúng
import com.officesync.communication_service.repository.UserRepository; // Repository của bạn
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.Collections;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Autowired private JwtTokenProvider tokenProvider;
    @Autowired private UserRepository userRepository; // Bạn cần tạo interface này nếu chưa có

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        try {
            String jwt = getJwtFromRequest(request);
            if (jwt != null && tokenProvider.validateToken(jwt)) {
                String email = tokenProvider.getEmailFromToken(jwt);
                
                // Tìm User trong DB chung
                User user = userRepository.findByEmail(email).orElse(null);
                
                if (user != null) {
                    // Xác thực thành công -> Cho phép Controller dùng @AuthenticationPrincipal
                    UsernamePasswordAuthenticationToken auth = new UsernamePasswordAuthenticationToken(
                            user, null, Collections.emptyList()); // Tạm thời để quyền trống hoặc lấy từ user.getRole()
                    SecurityContextHolder.getContext().setAuthentication(auth);
                }
            }
        } catch (Exception ex) {
            System.err.println("Lỗi xác thực user: " + ex.getMessage());
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