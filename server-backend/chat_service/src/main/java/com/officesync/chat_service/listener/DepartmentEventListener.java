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
@RabbitListener(queues = RabbitMQConfig.HR_EVENT_QUEUE)
    public void handleDepartmentEvent(DepartmentEventDTO event) {
        log.info("📩 [Chat] Nhận lệnh: {} - DeptID: {}", event.getEvent(), event.getDeptId());

        switch (event.getEvent()) {
            case "DEPT_CREATED":
                chatService.createDepartmentRoom(
                    event.getDeptId(), event.getDeptName(), 
                    event.getManagerId(), event.getMemberIds(), event.getCompanyId()
                );
                break;
            case "DEPT_DELETED":
                chatService.deleteDepartmentRoom(event.getDeptId());
                break;
            case "MEMBER_ADDED":
                chatService.addMemberToDepartmentRoom(event.getDeptId(), event.getMemberIds());
                break;
            case "MEMBER_REMOVED":
                chatService.removeMemberFromDepartmentRoom(event.getDeptId(), event.getMemberIds());
                break;
        }
    }
}