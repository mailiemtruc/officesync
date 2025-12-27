package com.officesync.core.service;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders; // [MỚI] Import để lấy tên Header
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.Header; // [MỚI] Import annotation Header
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

    // [QUAN TRỌNG] Thêm tham số @Header để phân loại tin nhắn
    @RabbitListener(queues = RabbitMQConfig.QUEUE_EMPLOYEE_SYNC)
    public void receiveEmployeeSyncEvent(String message, @Header(AmqpHeaders.RECEIVED_ROUTING_KEY) String routingKey) {
        try {
            System.out.println("--> [RabbitMQ] Nhận tin nhắn. Key: " + routingKey);

            // --- TRƯỜNG HỢP 1: XÓA USER (Routing key chứa từ "delete") ---
            if (routingKey.contains("delete")) {
                try {
                    // Message lúc này là ID dạng String (ví dụ: "101")
                    // .replaceAll("\"", "") để xử lý trường hợp ID bị bọc trong dấu ngoặc kép
                    Long userId = Long.parseLong(message.replaceAll("\"", "").trim());
                    
                    // Gọi hàm xóa (Bạn cần đảm bảo AuthService đã có hàm này)
                    authService.deleteUser(userId);
                    
                } catch (NumberFormatException e) {
                    System.err.println("Lỗi định dạng ID khi xóa: " + message);
                }
            } 
            
            // --- TRƯỜNG HỢP 2: TẠO HOẶC CẬP NHẬT (Routing key là create hoặc update) ---
            else {
                // Message lúc này là JSON Object
                EmployeeSyncEvent event = objectMapper.readValue(message, EmployeeSyncEvent.class);
                
                // Gọi hàm đồng bộ thông tin
                authService.syncEmployeeAccount(event);
            }

        } catch (Exception e) {
            System.err.println("Lỗi xử lý tin nhắn RabbitMQ: " + e.getMessage());
            e.printStackTrace();
        }
    }
}