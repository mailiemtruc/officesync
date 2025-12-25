package com.officesync.core.service;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.officesync.core.config.RabbitMQConfig;
import com.officesync.core.dto.EmployeeSyncEvent;

@Service
public class CoreConsumer {

    @Autowired
    private AuthService authService;

    // [SỬA ĐỔI] Chỉ lắng nghe 1 hàng đợi duy nhất
    @RabbitListener(queues = RabbitMQConfig.QUEUE_EMPLOYEE_SYNC)
    public void receiveEmployeeSyncEvent(EmployeeSyncEvent event) {
        System.out.println("--> [RabbitMQ] Core nhận sự kiện Employee Sync: " + event.getEmail());
        
        // Gọi hàm xử lý chung (Upsert)
        authService.syncEmployeeAccount(event);
    }
}