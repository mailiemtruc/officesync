package com.officesync.core.service;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.officesync.core.dto.UserStatusChangedEvent; // Import DTO
import com.officesync.core.model.User;
import com.officesync.core.repository.UserRepository;

@Service
public class UserService {

    @Autowired private UserRepository userRepository;
    
    // 🔴 1. Inject Producer
    @Autowired private RabbitMQProducer rabbitMQProducer;

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
            System.err.println("Lỗi gửi RabbitMQ status change: " + e.getMessage());
            // Không throw exception để tránh rollback việc update DB
        }
    }
}