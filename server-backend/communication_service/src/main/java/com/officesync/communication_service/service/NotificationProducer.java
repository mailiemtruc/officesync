package com.officesync.communication_service.service;

import com.officesync.communication_service.dto.NotificationEvent;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class NotificationProducer {

    @Autowired
    private RabbitTemplate rabbitTemplate;

    // Cấu hình khớp với bên Notification Service
    private final String EXCHANGE = "notification.exchange"; 
    private final String ROUTING_KEY = "notification.send";

    public void sendNotification(NotificationEvent event) {
        try {
            // Convert Object -> JSON và bắn đi
            rabbitTemplate.convertAndSend(EXCHANGE, ROUTING_KEY, event);
            System.out.println("--> [RabbitMQ] Sent Notification to User: " + event.getUserId());
        } catch (Exception e) {
            System.err.println("Lỗi gửi RabbitMQ: " + e.getMessage());
        }
    }
}