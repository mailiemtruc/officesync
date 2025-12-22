package com.officesync.hr_service.Producer;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import com.officesync.hr_service.Config.RabbitMQConfig;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeProducer {

    private final RabbitTemplate rabbitTemplate;

    public void sendEmployeeCreatedEvent(EmployeeSyncEvent event) {
        log.info("--> [RabbitMQ] Gửi yêu cầu tạo User sang Core Service: {}", event.getEmail());
        
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.EMPLOYEE_EXCHANGE,
            RabbitMQConfig.EMPLOYEE_ROUTING_KEY,
            event
        );
    }

    // [MỚI] Hàm gửi sự kiện CẬP NHẬT
    public void sendEmployeeUpdatedEvent(EmployeeSyncEvent event) {
        log.info("--> [RabbitMQ] Gửi yêu cầu CẬP NHẬT User sang Core Service: {}", event.getEmail());
        
        // Gửi với routing key "employee.update"
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.EMPLOYEE_EXCHANGE,
            RabbitMQConfig.EMPLOYEE_UPDATE_ROUTING_KEY,
            event
        );
    }
}