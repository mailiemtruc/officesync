package com.officesync.hr_service.Consumer;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders; // [MỚI] Để lấy Routing Key
import org.springframework.messaging.handler.annotation.Header; // [MỚI]
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper; // [MỚI]
import com.officesync.hr_service.Config.RabbitMQConfig;
import com.officesync.hr_service.DTO.UserCreatedEvent;
import com.officesync.hr_service.DTO.UserStatusChangedEvent;
import com.officesync.hr_service.Service.EmployeeService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeConsumer {

    private final EmployeeService employeeService;
    private final ObjectMapper objectMapper; // [MỚI] Inject ObjectMapper

    // [QUAN TRỌNG] Chỉ dùng 1 hàm duy nhất nhận String
    @RabbitListener(queues = RabbitMQConfig.QUEUE_COMPANY_CREATE)
    public void receiveMessage(String jsonMessage, @Header(AmqpHeaders.RECEIVED_ROUTING_KEY) String routingKey) {
        try {
            log.info("--> [Consumer] Nhận tin nhắn JSON từ Key: {}", routingKey);

            // Dựa vào Routing Key để biết phải ép kiểu sang class nào
            if (routingKey.contains("company.create")) {
                // Đây là UserCreatedEvent
                UserCreatedEvent event = objectMapper.readValue(jsonMessage, UserCreatedEvent.class);
                employeeService.createEmployeeFromEvent(event);
                
            } else if (routingKey.contains("user.status")) {
                // Đây là UserStatusChangedEvent
                UserStatusChangedEvent event = objectMapper.readValue(jsonMessage, UserStatusChangedEvent.class);
                employeeService.updateEmployeeStatusFromEvent(event);
            } else {
                log.warn("Không xác định được loại tin nhắn từ key: {}", routingKey);
            }

        } catch (Exception e) {
            log.error("Lỗi xử lý tin nhắn về HR: {}", e.getMessage());
            e.printStackTrace();
        }
    }
}