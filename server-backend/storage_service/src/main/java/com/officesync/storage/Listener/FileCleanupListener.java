package com.officesync.storage.Listener;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

import com.officesync.storage.service.FileStorageService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class FileCleanupListener {

    private final FileStorageService fileStorageService;

    // Lắng nghe hàng đợi "file.delete.queue"
    @RabbitListener(queues = "file.delete.queue")
    public void handleDeleteFileRequest(String fileName) {
        log.info("--> [RabbitMQ] Nhận lệnh xóa file: {}", fileName);
        try {
            fileStorageService.deleteFile(fileName);
            log.info("--> Đã xóa thành công.");
        } catch (Exception e) {
            log.error("Lỗi khi xóa file từ RabbitMQ: {}", e.getMessage());
            // Nếu muốn retry thì ném exception ra, RabbitMQ sẽ gửi lại sau
        }
    }
}