package com.officesync.hr_service.Consumer;

import com.officesync.hr_service.Config.RabbitMQConfig;
import com.officesync.hr_service.Service.EmployeeService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class SyncRequestConsumer {

    private final EmployeeService employeeService;

    @RabbitListener(queues = RabbitMQConfig.SYNC_REQUEST_QUEUE)
    public void handleSyncRequest(String message) {
        if ("START_SYNC_ALL".equals(message)) {
            log.info("📩 [MQ] Nhận tín hiệu yêu cầu đồng bộ từ Task Service.");
            // Gọi hàm có sẵn của bạn để bắn toàn bộ dữ liệu qua MQ
            employeeService.forceSyncAllDataToMQ();
            log.info("✅ [MQ] Đã hoàn thành việc đẩy ngược dữ liệu cho Task Service.");
        }
    }
}