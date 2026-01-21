package com.officesync.hr_service.Producer;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.officesync.hr_service.Config.RabbitMQConfig;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.NotificationEvent;
import com.officesync.hr_service.DTO.DepartmentSyncEvent; // Import mới
//import com.officesync.hr_service.Producer.EmployeeProducer; // Import mới
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.core.MessageBuilder;
import org.springframework.amqp.core.MessageProperties;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeProducer {

    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper; // [MỚI] Inject ObjectMapper

    private static final String INTERNAL_EXCHANGE = "internal.exchange";
    private static final String ATTENDANCE_ROUTING_KEY = "user.sync";
  //  private final EmployeeProducer employeeProducer;
    // 1. Gửi TẠO MỚI
    public void sendEmployeeCreatedEvent(EmployeeSyncEvent event) {
        try {
            log.info("--> [RabbitMQ] Gửi yêu cầu tạo User: {}", event.getEmail());
            
            // [QUAN TRỌNG] Chuyển Object -> String JSON
            String jsonMessage = objectMapper.writeValueAsString(event);
            
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EMPLOYEE_EXCHANGE,
                RabbitMQConfig.EMPLOYEE_ROUTING_KEY,
                jsonMessage // Gửi chuỗi String đi, không gửi Object nữa
            );
        } catch (Exception e) {
            log.error("Lỗi parse JSON Create: {}", e.getMessage());
        }
    }

    // 2. Gửi CẬP NHẬT
    public void sendEmployeeUpdatedEvent(EmployeeSyncEvent event) {
        try {
            log.info("--> [RabbitMQ] Gửi yêu cầu CẬP NHẬT User: {}", event.getEmail());
            
            // [QUAN TRỌNG] Chuyển Object -> String JSON
            String jsonMessage = objectMapper.writeValueAsString(event);
            
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EMPLOYEE_EXCHANGE,
                RabbitMQConfig.EMPLOYEE_UPDATE_ROUTING_KEY,
                jsonMessage // Gửi chuỗi String
            );
        } catch (Exception e) {
            log.error("Lỗi parse JSON Update: {}", e.getMessage());
        }
    }

    // 3. Gửi XÓA USER
    public void sendEmployeeDeletedEvent(Long userId) {
        log.info("--> [RabbitMQ] Delete User ID: {}", userId);
        // ID là số (Long), gửi trực tiếp cũng được, hoặc chuyển thành String cho an toàn tuyệt đối
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.EMPLOYEE_EXCHANGE,
            RabbitMQConfig.EMPLOYEE_DELETE_ROUTING_KEY,
            String.valueOf(userId) // [KHUYÊN DÙNG] Gửi String ID
        );
    }
    
    // 4. Gửi XÓA FILE
    public void sendDeleteFileEvent(String fileName) {
        log.info("--> [RabbitMQ] Gửi yêu cầu XÓA file: {}", fileName);
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.FILE_EXCHANGE,
            RabbitMQConfig.FILE_DELETE_ROUTING_KEY,
            fileName // String sẵn rồi thì cứ gửi
        );
    }
    // [MỚI] Hàm gửi thông báo - SỬA LẠI
    public void sendNotification(NotificationEvent event) {
        try {
            log.info("--> [RabbitMQ] Pushing Notification to User: {}", event.getUserId());
            
            // SAI: String jsonMessage = objectMapper.writeValueAsString(event); 
            // ĐÚNG: Gửi thẳng Object event. Converter sẽ tự biến nó thành JSON chuẩn.
            
            rabbitTemplate.convertAndSend(
                RabbitMQConfig.NOTIFICATION_EXCHANGE,
                RabbitMQConfig.NOTIFICATION_ROUTING_KEY,
                event 
            );
        } catch (Exception e) {
            log.error("Lỗi gửi Notification Event: {}", e.getMessage());
        }
    }

    public void sendToAttendance(EmployeeSyncEvent event) {
        try {
            log.info("--> [HR -> Attendance] Gửi thông tin User ID: {}", event.getId());
            
            // Chuyển sang JSON String để khớp với Consumer bên Attendance 
            // (Vì bên Attendance bạn đang dùng UserSyncConsumer nhận String message)
            String jsonMessage = objectMapper.writeValueAsString(event);

            rabbitTemplate.convertAndSend(
                INTERNAL_EXCHANGE,
                ATTENDANCE_ROUTING_KEY,
                jsonMessage
            );
        } catch (Exception e) {
            log.error("Lỗi gửi sang Attendance: {}", e.getMessage());
        }
    }

// [CHAT] Gửi sự kiện sang Chat Service--------------------------------------------------
 public void sendDepartmentEvent(DepartmentSyncEvent event) {
        try {
            log.info("--> [RabbitMQ] Gửi event Department sang Chat (Raw JSON): {}", event.getEvent());

            // 1. Chuyển Object -> JSON String
            String json = objectMapper.writeValueAsString(event);

            // 2. Đóng gói thành Message chuẩn RabbitMQ (Byte Array)
            // Việc này bỏ qua mọi Config Converter của HR Service
            Message message = MessageBuilder
                    .withBody(json.getBytes()) // Chuyển String thành Bytes
                    .setContentType(MessageProperties.CONTENT_TYPE_JSON) // Gắn nhãn "Đây là JSON"
                    .build();

            // 3. Gửi gói tin đi
            rabbitTemplate.send(
                RabbitMQConfig.HR_EXCHANGE,
                RabbitMQConfig.HR_ROUTING_KEY,
                message
            );
            
            log.info("✅ Đã gửi thành công gói tin JSON sang Chat!");
        } catch (Exception e) {
            log.error("❌ Lỗi gửi event Department: {}", e.getMessage());
            e.printStackTrace();
        }
    }

   // 1. Gửi TẠO MỚI (SỬA LẠI: Object -> String JSON)
    public void sendEmployeeCreatedEventDirect(EmployeeSyncEvent event) {
        try {
            log.info("--> [RabbitMQ-Sync] Gửi JSON tạo User: {}", event.getEmail());
            
            // [FIX] Convert sang String JSON
            String jsonMessage = objectMapper.writeValueAsString(event);

            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EMPLOYEE_EXCHANGE,
                RabbitMQConfig.EMPLOYEE_ROUTING_KEY,
                jsonMessage // Gửi String thay vì Object
            );
        } catch (Exception e) {
            log.error("Lỗi gửi Object Create: {}", e.getMessage());
        }
    }

    // 2. Gửi CẬP NHẬT (SỬA LẠI: Object -> String JSON)
    public void sendEmployeeUpdatedEventDirect(EmployeeSyncEvent event) {
        try {
            log.info("--> [RabbitMQ-Sync] Gửi JSON cập nhật User: {}", event.getEmail());
            
            // [FIX] Convert sang String JSON
            String jsonMessage = objectMapper.writeValueAsString(event);

            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EMPLOYEE_EXCHANGE,
                RabbitMQConfig.EMPLOYEE_UPDATE_ROUTING_KEY,
                jsonMessage // Gửi String thay vì Object
            );
        } catch (Exception e) {
            log.error("Lỗi gửi Object Update: {}", e.getMessage());
        }
    }

    // 3. Gửi PHÒNG BAN (SỬA LẠI: Object -> String JSON cho đồng bộ)
    public void sendDepartmentEventDirect(DepartmentSyncEvent event) {
        try {
            log.info("--> [RabbitMQ-Sync] Gửi JSON Department: {}", event.getEvent());
            
            // [FIX] Nếu bên Chat/Task nhận String thì phải convert, nếu nhận Object thì giữ nguyên.
            // Tuy nhiên để an toàn và đồng bộ với phong cách code trên, nên chuyển thành JSON String.
            String jsonMessage = objectMapper.writeValueAsString(event);

            rabbitTemplate.convertAndSend(
                RabbitMQConfig.HR_EXCHANGE,
                RabbitMQConfig.HR_ROUTING_KEY,
                jsonMessage 
            );
        } catch (Exception e) {
            log.error("Lỗi gửi Object Department: {}", e.getMessage());
        }
    }
}