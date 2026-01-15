package com.officesync.chat_service.listener;

import com.officesync.chat_service.config.RabbitMQConfig;
import com.officesync.chat_service.dto.DepartmentEventDTO;
import com.officesync.chat_service.service.ChatService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
@Slf4j
@RequiredArgsConstructor
public class DepartmentEventListener {

    private final ChatService chatService;

    // Lắng nghe Queue của HR mà ta vừa cấu hình
    @RabbitListener(queues = RabbitMQConfig.HR_EVENT_QUEUE)
    public void handleDepartmentEvent(DepartmentEventDTO event) {
        log.info("📩 [RabbitMQ] Nhận sự kiện HR: {}", event);

        if ("DEPT_CREATED".equals(event.getEvent())) {
            chatService.createDepartmentRoom(
                event.getDeptId(), 
                event.getDeptName(), 
                event.getManagerId(), 
                event.getMemberIds()
            );
        }
    }
}