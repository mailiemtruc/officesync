package com.officesync.core.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper; // [MỚI]
import com.officesync.core.config.RabbitMQConfig;
import com.officesync.core.dto.UserCreatedEvent;
import com.officesync.core.dto.UserStatusChangedEvent;

@Service
public class RabbitMQProducer {

    private static final Logger LOGGER = LoggerFactory.getLogger(RabbitMQProducer.class);

    @Autowired
    private RabbitTemplate rabbitTemplate;

    @Autowired
    private ObjectMapper objectMapper; // [MỚI] Inject để chuyển đổi JSON

    // 1. Gửi sự kiện tạo User (Phản hồi về HR)
    public void sendUserCreatedEvent(UserCreatedEvent event) {
        try {
            LOGGER.info(String.format("--> RabbitMQ Sending User Create: %s", event.getEmail()));
            
            // [QUAN TRỌNG] Object -> JSON String
            String jsonMessage = objectMapper.writeValueAsString(event);

            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_INTERNAL, 
                RabbitMQConfig.ROUTING_KEY_COMPANY_CREATE, 
                jsonMessage // Gửi String
            );
        } catch (Exception e) {
            LOGGER.error("Lỗi parse JSON UserCreated: " + e.getMessage());
        }
    }

    // 2. Gửi sự kiện thay đổi trạng thái
    public void sendUserStatusChangedEvent(UserStatusChangedEvent event) {
        try {
            LOGGER.info(String.format("--> RabbitMQ Sending Status Change: %s -> %s", event.getUserId(), event.getStatus()));
            
            // [QUAN TRỌNG] Object -> JSON String
            String jsonMessage = objectMapper.writeValueAsString(event);
            
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_INTERNAL, 
                RabbitMQConfig.ROUTING_KEY_USER_STATUS, 
                jsonMessage // Gửi String
            );
        } catch (Exception e) {
            LOGGER.error("Lỗi parse JSON StatusChange: " + e.getMessage());
        }
    }
}