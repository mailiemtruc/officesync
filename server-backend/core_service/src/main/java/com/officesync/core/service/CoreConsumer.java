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

    // Lắng nghe queue mà HR bắn vào
    @RabbitListener(queues = RabbitMQConfig.QUEUE_EMPLOYEE_CREATE)
    public void receiveEmployeeSyncEvent(EmployeeSyncEvent event) {
        System.out.println("--> [RabbitMQ] Core nhận yêu cầu tạo User: " + event.getEmail());
        
        // Gọi Service xử lý
        authService.createEmployeeAccount(event);
    }
}