package com.officesync.task_service.config;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import lombok.extern.slf4j.Slf4j;

@Configuration
@Slf4j
public class TaskSyncTrigger {

    @Bean
    CommandLineRunner triggerSyncOnStartup(RabbitTemplate rabbitTemplate) {
        return args -> {
            log.info("🚀 [Task Service] Đang khởi động. Gửi tín hiệu yêu cầu đồng bộ qua RabbitMQ...");
            try {
                // Gửi một tin nhắn đơn giản để "đánh thức" HR Service
                rabbitTemplate.convertAndSend(
                    RabbitMQConfig.SYNC_REQUEST_EXCHANGE, 
                    RabbitMQConfig.SYNC_REQUEST_ROUTING_KEY, 
                    "START_SYNC_ALL"
                );
                log.info("✅ [MQ] Đã gửi tín hiệu yêu cầu. Chờ dữ liệu đổ về...");
            } catch (Exception e) {
                log.error("❌ [MQ] Không thể gửi yêu cầu đồng bộ: {}", e.getMessage());
            }
        };
    }
}