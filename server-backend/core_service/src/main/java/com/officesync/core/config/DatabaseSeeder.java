package com.officesync.core.config;

import java.time.LocalDate;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.officesync.core.dto.UserCreatedEvent; // Import DTO
import com.officesync.core.model.Company;
import com.officesync.core.model.User;
import com.officesync.core.repository.UserRepository;
import com.officesync.core.service.RabbitMQProducer; // Import Producer

@Configuration
public class DatabaseSeeder {

    // Inject Producer để bắn message
    @Autowired
    private RabbitMQProducer rabbitMQProducer;

    @Bean
    CommandLineRunner initDatabase(UserRepository userRepository, 
                                   PasswordEncoder passwordEncoder) {
        return args -> {
            // --- CHỈ TẠO SUPER ADMIN ---
            // Company là null vì Super Admin không thuộc công ty nào cụ thể
            createUserIfNotFound(userRepository, passwordEncoder, 
                "admin@system.com", "Super Admin", "SUPER_ADMIN", null);
        };
    }

    private void createUserIfNotFound(UserRepository userRepository, 
                                      PasswordEncoder passwordEncoder,
                                      String email, String fullName, String role, Company company) {
        if (userRepository.findByEmail(email).isEmpty()) {
            User user = new User();
            user.setEmail(email);
            user.setFullName(fullName);
            // Mật khẩu mặc định là 123456
            user.setPassword(passwordEncoder.encode("123456")); 
            user.setRole(role);
            
            // Nếu có company thì set ID, nếu null (Super Admin) thì bỏ qua
            if (company != null) {
                user.setCompanyId(company.getId());
            }
            
            // Dữ liệu giả định bắt buộc
            user.setMobileNumber("0900000000");
            user.setDateOfBirth(LocalDate.of(1990, 1, 1));
            user.setStatus("ACTIVE");

            // 1. Lưu vào DB
            User savedUser = userRepository.save(user);
            System.out.println("--> Đã tạo User: " + email + " (Pass: 123456)");

            // 2. [FIX] Bắn sự kiện sang RabbitMQ để HR/Profile Service đồng bộ
            try {
                UserCreatedEvent event = new UserCreatedEvent();
                event.setId(savedUser.getId());
                event.setCompanyId(savedUser.getCompanyId()); // Có thể null với Super Admin
                event.setEmail(savedUser.getEmail());
                event.setFullName(savedUser.getFullName());
                event.setMobileNumber(savedUser.getMobileNumber());
                event.setDateOfBirth(savedUser.getDateOfBirth());
                event.setRole(savedUser.getRole());
                event.setStatus(savedUser.getStatus());

                rabbitMQProducer.sendUserCreatedEvent(event);
                System.out.println("    -> [Seeder] Đã gửi sự kiện UserCreatedEvent cho " + email);
            } catch (Exception e) {
                System.err.println("    -> [Seeder] Lỗi gửi RabbitMQ: " + e.getMessage());
            }
        }
    }
}