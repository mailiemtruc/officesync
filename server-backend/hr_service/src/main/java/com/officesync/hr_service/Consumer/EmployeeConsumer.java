package com.officesync.hr_service.Consumer;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

import com.officesync.hr_service.Config.RabbitMQConfig;
import com.officesync.hr_service.DTO.UserCreatedEvent;
import com.officesync.hr_service.Service.EmployeeService;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class EmployeeConsumer {

    private final EmployeeService employeeService;

    @RabbitListener(queues = RabbitMQConfig.QUEUE_COMPANY_CREATE)
    public void receiveUserCreatedEvent(UserCreatedEvent event) {
        employeeService.createEmployeeFromEvent(event);
    }
}