// com.officesync.task_service.consumer.EmployeeSyncConsumer.java
package com.officesync.task_service.consumer;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.officesync.task_service.config.RabbitMQConfig;
import com.officesync.task_service.dto.EmployeeSyncEvent;
import com.officesync.task_service.service.TaskSyncService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;
import org.springframework.amqp.core.Message;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeSyncConsumer {

    private final ObjectMapper objectMapper;
    private final TaskSyncService syncService;

    @RabbitListener(queues = RabbitMQConfig.TASK_SYNC_QUEUE)
    public void receive(Message message) {
        try {
            String routingKey = message.getMessageProperties().getReceivedRoutingKey();
            String payload = new String(message.getBody());
            
            log.info("--> MQ Event Received: Key={} Payload={}", routingKey, payload);

            if (routingKey.startsWith("employee.")) {
                if (routingKey.endsWith("delete")) {
                    String idStr = payload.replaceAll("\"", "");
                    syncService.deleteEmployee(Long.parseLong(idStr));
                } else {
                    // Update hoặc Create
                    EmployeeSyncEvent event = objectMapper.readValue(payload, EmployeeSyncEvent.class);
                    syncService.upsertEmployee(event);
                }
            } 
        } catch (Exception e) {
            log.error("Error processing MQ message: {}", e.getMessage());
        }
    }
}