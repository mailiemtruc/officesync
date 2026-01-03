package com.officesync.communication_service.service;

import com.fasterxml.jackson.databind.ObjectMapper; // Nhớ import cái này
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

    // ✅ 1. Inject ObjectMapper để parse JSON
    @Autowired
    private ObjectMapper objectMapper;

    @RabbitListener(queues = RabbitMQConfig.QUEUE_NEWSFEED_USER_SYNC)
    public void receiveUserCreatedEvent(String message) { // ✅ 2. Đổi tham số nhận vào thành String
        try {
            // ✅ 3. Tự tay chuyển String JSON thành Object
            UserCreatedEvent event = objectMapper.readValue(message, UserCreatedEvent.class);

            System.out.println("--> RabbitMQ received User: " + event.getEmail());

            // Kiểm tra xem user đã tồn tại chưa để tránh trùng lặp
            if (userRepository.findByEmail(event.getEmail()).isEmpty()) {
                User newUser = new User();
                newUser.setId(event.getId()); 
                newUser.setEmail(event.getEmail());
                newUser.setFullName(event.getFullName());
                newUser.setRole(event.getRole());
                newUser.setCompanyId(event.getCompanyId());
                newUser.setPassword("HASHED_FROM_CORE"); 
                // Set avatar mặc định nếu null
                if (newUser.getAvatarUrl() == null) {
                    newUser.setAvatarUrl("https://ui-avatars.com/api/?name=" + event.getFullName().replace(" ", "+"));
                }

                userRepository.save(newUser);
                System.out.println("--> Đã đồng bộ User vào Communication DB: " + newUser.getEmail());
            }
        } catch (Exception e) {
            System.err.println("Lỗi khi đồng bộ User: " + e.getMessage());
            e.printStackTrace(); // In ra lỗi chi tiết để debug nếu parse sai
        }
    }
}