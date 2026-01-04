package com.officesync.notification_service.consumer;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import com.officesync.notification_service.DTO.NotificationEvent;
import com.officesync.notification_service.service.NotificationService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class NotificationConsumer {

    private final NotificationService notificationService;
    // Không cần ObjectMapper ở đây nữa

    @RabbitListener(queues = "notification.queue") 
    public void receiveNotification(NotificationEvent event) { // [SỬA] Nhận thẳng Object
        try {
            log.info("--> [RabbitMQ] Received Notification Object: {}", event);

            // Gọi Service xử lý
            notificationService.sendNotification(
                event.getUserId(),
                event.getTitle(),
                event.getBody(),
                event.getType(),
                event.getReferenceId()
            );

        } catch (Exception e) {
            log.error("Lỗi xử lý tin nhắn RabbitMQ: {}", e.getMessage());
        }
    }
}