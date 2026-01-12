package com.officesync.core.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.officesync.core.dto.UserCreatedEvent;
import com.officesync.core.dto.UserStatusChangedEvent; // Import DTO
import com.officesync.core.model.User;
import com.officesync.core.repository.UserRepository;

@Service
public class UserService {

    @Autowired private UserRepository userRepository;
    
    // 🔴 1. Inject Producer
    @Autowired private RabbitMQProducer rabbitMQProducer;

    @Autowired private PasswordEncoder passwordEncoder;

    public List<User> getUsersByCompanyId(Long companyId) {
        return userRepository.findByCompanyId(companyId);
    }

    public void updateUserStatus(Long userId, String status) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        // Cập nhật Database
        user.setStatus(status);
        userRepository.save(user);
        
        // 🔴 2. Bắn MQ sang Profile Service (hoặc các service khác)
        try {
            UserStatusChangedEvent event = new UserStatusChangedEvent(userId, status);
            rabbitMQProducer.sendUserStatusChangedEvent(event);
        } catch (Exception e) {
            System.err.println("Error submitting RabbitMQ status change: " + e.getMessage());
            // Không throw exception để tránh rollback việc update DB
        }
    }

    public User createSuperAdmin(String fullName, String email, String password, String mobile) {
        
        // 1. Kiểm tra trùng Email
        if (userRepository.findByEmail(email).isPresent()) {
            throw new RuntimeException("Email '" + email + "' t already exists in the system!");
        }

        // 2. Kiểm tra trùng Số điện thoại
        // Lưu ý: Đảm bảo trong UserRepository đã có hàm findByMobileNumber
        if (userRepository.findByMobileNumber(mobile).isPresent()) {
            throw new RuntimeException("Phone number '" + mobile + "' it already exists in the system!");
        }

        // 3. Tạo Entity User
        User admin = new User();
        admin.setFullName(fullName);
        admin.setEmail(email);
        admin.setPassword(passwordEncoder.encode(password)); // Mã hóa pass
        admin.setMobileNumber(mobile);
        
        // Cố định các trường cho Super Admin
        admin.setRole("SUPER_ADMIN");
        admin.setStatus("ACTIVE");
        admin.setCompanyId(null); 
        admin.setDateOfBirth(java.time.LocalDate.now()); // Hoặc nhận từ tham số nếu muốn

        // 4. Lưu vào DB
        User savedUser = userRepository.save(admin);

        // 5. Bắn RabbitMQ (để Profile Service lưu thông tin nếu cần)
        try {
            UserCreatedEvent event = new UserCreatedEvent();
            event.setId(savedUser.getId());
            event.setEmail(savedUser.getEmail());
            event.setFullName(savedUser.getFullName());
            event.setRole(savedUser.getRole());
            event.setStatus(savedUser.getStatus());
            event.setCompanyId(null);
            event.setMobileNumber(savedUser.getMobileNumber()); // Đừng quên dòng này
            
            rabbitMQProducer.sendUserCreatedEvent(event);
        } catch (Exception e) {
            System.err.println("Error submitting RabbitMQ when creating Admin: " + e.getMessage());
        }

        return savedUser;
    }
}