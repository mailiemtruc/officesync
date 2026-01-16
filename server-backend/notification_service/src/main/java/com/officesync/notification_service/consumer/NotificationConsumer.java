// package com.officesync.notification_service.consumer;

// import org.springframework.amqp.rabbit.annotation.RabbitListener;
// import org.springframework.stereotype.Component;

// import com.officesync.notification_service.DTO.NotificationEvent;
// import com.officesync.notification_service.service.NotificationService;

// import lombok.RequiredArgsConstructor;
// import lombok.extern.slf4j.Slf4j;

// @Component
// @RequiredArgsConstructor
// @Slf4j
// public class NotificationConsumer {

//     private final NotificationService notificationService;
//     // Không cần ObjectMapper ở đây nữa

//     @RabbitListener(queues = "notification.queue") 
//     public void receiveNotification(NotificationEvent event) { // [SỬA] Nhận thẳng Object
//         try {
//             log.info("--> [RabbitMQ] Received Notification Object: {}", event);

//             // Gọi Service xử lý
//             notificationService.sendNotification(
//                 event.getUserId(),
//                 event.getTitle(),
//                 event.getBody(),
//                 event.getType(),
//                 event.getReferenceId()
//             );

//         } catch (Exception e) {
//             log.error("Lỗi xử lý tin nhắn RabbitMQ: {}", e.getMessage());
//         }
//     }
// }
package com.officesync.notification_service.consumer;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.officesync.notification_service.DTO.NotificationEvent; // Class DTO của bên Notification
import com.officesync.notification_service.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message; // 👈 QUAN TRỌNG: Import cái này
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

@Component
@RequiredArgsConstructor
@Slf4j
public class NotificationConsumer {

    private final NotificationService notificationService;
    private final ObjectMapper objectMapper; // Spring tự inject cái này

    @RabbitListener(queues = "notification.queue")
    public void receiveNotification(Message message) { // 👈 Sửa tham số thành Message
        try {
            // 1. Lấy nội dung JSON thô từ message
            String jsonBody = new String(message.getBody(), StandardCharsets.UTF_8);
            log.info("--> [RabbitMQ] Raw JSON received: {}", jsonBody);

            // 2. Tự tay Map JSON đó vào DTO của bên Notification (Bỏ qua việc lệch package)
            NotificationEvent event = objectMapper.readValue(jsonBody, NotificationEvent.class);

            log.info("--> Mapping thành công! Gửi cho UserID: {}", event.getUserId());

            // 3. Gọi Service xử lý
            notificationService.sendNotification(
                event.getUserId(),
                event.getTitle(),
                event.getBody(),
                event.getType(),
                event.getReferenceId()
            );

        } catch (Exception e) {
            log.error("❌ Lỗi xử lý RabbitMQ: {}", e.getMessage());
            e.printStackTrace();
        }
    }
}