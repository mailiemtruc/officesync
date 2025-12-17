package com.officesync.core.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.officesync.core.config.RabbitMQConfig;
import com.officesync.core.dto.UserCreatedEvent; // Import DTO mới

@Service
public class RabbitMQProducer {

    private static final Logger LOGGER = LoggerFactory.getLogger(RabbitMQProducer.class);

    @Autowired
    private RabbitTemplate rabbitTemplate;

    // Đổi tham số đầu vào thành UserCreatedEvent
    public void sendUserCreatedEvent(UserCreatedEvent event) {
        LOGGER.info(String.format("--> RabbitMQ Sending User Event: %s", event.toString()));
        
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.EXCHANGE_INTERNAL, 
            RabbitMQConfig.ROUTING_KEY_COMPANY_CREATE, 
            event
        );
    }
}