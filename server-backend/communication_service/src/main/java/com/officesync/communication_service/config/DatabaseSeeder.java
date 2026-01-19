package com.officesync.communication_service.config;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.officesync.communication_service.model.User;
import com.officesync.communication_service.repository.UserRepository;

@Configuration
public class DatabaseSeeder {

    @Bean
    CommandLineRunner initDatabase(UserRepository userRepository) {
        return args -> {
            // ✅ TRUYỀN THÊM ID (1, 2, 3...) ĐỂ KHỚP VỚI CORE SERVICE
            
            // 1. Admin
            createSimpleUser(userRepository, 1L, "admin@system.com", "Super Admin", "SUPER_ADMIN");

        
        };
    }

    // 👇 Thêm tham số Long id vào hàm này
    private void createSimpleUser(UserRepository userRepository, Long id, String email, String fullName, String role) {
        if (userRepository.findByEmail(email).isEmpty()) {
            User user = new User();
            user.setId(id); // 👈 BẮT BUỘC PHẢI CÓ DÒNG NÀY
            user.setEmail(email);
            user.setFullName(fullName);
            user.setRole(role);
            user.setCompanyId(1L); // Set tạm company = 1
            
            user.setAvatarUrl("https://ui-avatars.com/api/?name=" + fullName.replace(" ", "+"));
            
            userRepository.save(user);
            System.out.println("--> Communication DB: Đã tạo user ID=" + id + " : " + email);
        }
    }
}