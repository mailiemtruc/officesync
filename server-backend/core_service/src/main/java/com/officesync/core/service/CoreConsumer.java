package com.officesync.core.service;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper; // [MỚI] Import
import com.officesync.core.config.RabbitMQConfig;
import com.officesync.core.dto.EmployeeSyncEvent;

@Service
public class CoreConsumer {

    @Autowired
    private AuthService authService;

    @Autowired
    private ObjectMapper objectMapper; // [MỚI] Inject ObjectMapper để dịch JSON

    // [QUAN TRỌNG] Nhận String thay vì Object
    @RabbitListener(queues = RabbitMQConfig.QUEUE_EMPLOYEE_SYNC)
    public void receiveEmployeeSyncEvent(String jsonMessage) {
        try {
            System.out.println("--> [RabbitMQ] Core nhận chuỗi JSON: " + jsonMessage);
            
            // [THỦ CÔNG] Tự ép chuỗi JSON thành Object của Core
            EmployeeSyncEvent event = objectMapper.readValue(jsonMessage, EmployeeSyncEvent.class);
            
            // Gọi hàm xử lý
            authService.syncEmployeeAccount(event);
            
        } catch (Exception e) {
            System.err.println("Lỗi đọc tin nhắn JSON: " + e.getMessage());
            e.printStackTrace();
        }
    }
}