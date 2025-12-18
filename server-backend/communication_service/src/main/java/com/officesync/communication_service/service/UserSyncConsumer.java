package com.officesync.communication_service.service;

import com.officesync.communication_service.config.RabbitMQConfig;
import com.officesync.communication_service.dto.UserCreatedEvent;
import com.officesync.communication_service.model.User;
import com.officesync.communication_service.repository.UserRepository;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class UserSyncConsumer {

    @Autowired
    private UserRepository userRepository;

    @RabbitListener(queues = RabbitMQConfig.QUEUE_NEWSFEED_USER_SYNC)
    public void receiveUserCreatedEvent(UserCreatedEvent event) {
        try {
            System.out.println("--> RabbitMQ received User: " + event.getEmail());

            // Kiểm tra xem user đã tồn tại chưa để tránh trùng lặp
            if (userRepository.findByEmail(event.getEmail()).isEmpty()) {
                User newUser = new User();
                newUser.setId(event.getId()); // Quan trọng: Giữ nguyên ID từ Core
                newUser.setEmail(event.getEmail());
                newUser.setFullName(event.getFullName());
                newUser.setRole(event.getRole());
                newUser.setCompanyId(event.getCompanyId());
                newUser.setPassword("HASHED_FROM_CORE"); // Không quan trọng bên này

                userRepository.save(newUser);
                System.out.println("--> Đã đồng bộ User vào Communication DB: " + newUser.getEmail());
            }
        } catch (Exception e) {
            System.err.println("Lỗi khi đồng bộ User: " + e.getMessage());
        }
    }
}