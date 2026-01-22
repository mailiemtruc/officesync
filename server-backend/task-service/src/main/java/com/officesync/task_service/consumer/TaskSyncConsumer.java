package com.officesync.task_service.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.officesync.task_service.config.RabbitMQConfig;
import com.officesync.task_service.dto.DepartmentSyncEvent;
import com.officesync.task_service.dto.EmployeeSyncEvent;
import com.officesync.task_service.service.TaskSyncService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.support.AmqpHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class TaskSyncConsumer {

    private final TaskSyncService syncService;
    private final ObjectMapper objectMapper;

    @RabbitListener(queues = RabbitMQConfig.TASK_EMPLOYEE_SYNC_QUEUE)
    public void consumeEmployeeEvent(Message message, @Header(AmqpHeaders.RECEIVED_ROUTING_KEY) String routingKey) {
        try {
            if (routingKey.contains("employee.delete")) {
                String body = new String(message.getBody());
                Long idToDelete = Long.parseLong(body.replace("\"", ""));
                syncService.deleteEmployee(idToDelete);
                return;
            }

            JsonNode node = objectMapper.readTree(message.getBody());
            EmployeeSyncEvent event = node.isTextual() 
                ? objectMapper.readValue(node.asText(), EmployeeSyncEvent.class)
                : objectMapper.treeToValue(node, EmployeeSyncEvent.class);

            if (event != null && event.getId() != null) {
                syncService.upsertEmployee(event);
                log.info("✅ [MQ Sync] Đồng bộ User: {} (ID: {})", event.getFullName(), event.getId());
            }
        } catch (Exception e) {
            log.error("❌ Lỗi Employee Event: {}", e.getMessage());
        }
    }

    @RabbitListener(queues = RabbitMQConfig.TASK_DEPT_SYNC_QUEUE)
    public void consumeDeptEvent(Message message) {
        try {
            // SỬA TẠI ĐÂY: Xử lý tương tự Employee để tránh lỗi "no String-argument constructor"
            JsonNode node = objectMapper.readTree(message.getBody());
            DepartmentSyncEvent event = node.isTextual()
                ? objectMapper.readValue(node.asText(), DepartmentSyncEvent.class)
                : objectMapper.treeToValue(node, DepartmentSyncEvent.class);

            if (event != null && event.getDeptId() != null) {
                if ("DEPT_DELETED".equals(event.getEvent())) {
                    syncService.deleteDepartment(event.getDeptId());
                    log.info("🗑️ [MQ Dept] Đã xóa phòng ban ID: {}", event.getDeptId());
                } else {
                    // Khi lỗi giải mã được sửa, hàm upsertDepartment sẽ nhận được managerId
                    syncService.upsertDepartment(event);
                    log.info("🏢 [MQ Dept] Đồng bộ phòng ban: {} (Manager ID: {})", 
                        event.getDeptName(), event.getManagerId());
                }
            }
        } catch (Exception e) {
            log.error("❌ Lỗi giải mã dữ liệu Phòng ban: {}", e.getMessage());
        }
    }
    
}