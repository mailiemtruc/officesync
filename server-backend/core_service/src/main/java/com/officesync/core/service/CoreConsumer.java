package com.officesync.core.service;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.officesync.core.config.RabbitMQConfig;
import com.officesync.core.dto.EmployeeSyncEvent;

@Service
public class CoreConsumer {

    @Autowired
    private AuthService authService;

    @Autowired
    private ObjectMapper objectMapper;

    // 1. [QUAN TRỌNG] Inject cái service bắn WebSocket vào đây
    @Autowired
    private SecurityNotificationService securityNotificationService;

    @RabbitListener(queues = RabbitMQConfig.QUEUE_EMPLOYEE_SYNC)
    public void receiveEmployeeSyncEvent(String message, @Header(AmqpHeaders.RECEIVED_ROUTING_KEY) String routingKey) {
        try {
            System.out.println("--> [RabbitMQ] Nhận tin nhắn. Key: " + routingKey);

            // --- TRƯỜNG HỢP 1: XÓA USER ---
            if (routingKey.contains("delete")) {
                try {
                    Long userId = Long.parseLong(message.replaceAll("\"", "").trim());
                    authService.deleteUser(userId);
                    
                    // [THÊM MỚI] Xóa xong thì bắn WebSocket đá user ra luôn
                    securityNotificationService.notifyUserLocked(userId); 
                    
                } catch (NumberFormatException e) {
                    System.err.println("Lỗi định dạng ID khi xóa: " + message);
                }
            } 
            
            // --- TRƯỜNG HỢP 2: TẠO HOẶC CẬP NHẬT (Bao gồm cả Khoá) ---
            else {
                EmployeeSyncEvent event = objectMapper.readValue(message, EmployeeSyncEvent.class);
                
                // Gọi hàm lưu vào DB
                authService.syncEmployeeAccount(event); 

                // [LOGIC MỚI - QUAN TRỌNG]
                // Kiểm tra xem sự kiện update này có phải là KHOÁ tài khoản không?
                // (Giả sử trong EmployeeSyncEvent có trường status)
                if ("LOCKED".equalsIgnoreCase(event.getStatus()) || "INACTIVE".equalsIgnoreCase(event.getStatus())) {
                    
                    System.out.println("🚨 Phát hiện lệnh LOCK cho User: " + event.getId());
                    
                    // Bắn WebSocket ngay tại đây!
                    securityNotificationService.notifyUserLocked(event.getId());
                }
            }

        } catch (Exception e) {
            System.err.println("Lỗi xử lý tin nhắn RabbitMQ: " + e.getMessage());
            e.printStackTrace();
        }
    }
}