package com.officesync.attendance_service.consumer;

import java.util.List;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper; // [MỚI] Import thư viện parse JSON
import com.officesync.attendance_service.config.RabbitMQConfig;
import com.officesync.attendance_service.dto.CompanyConfigEvent;
import com.officesync.attendance_service.model.OfficeConfig;
import com.officesync.attendance_service.repository.OfficeConfigRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class CompanyConfigConsumer {

    private final OfficeConfigRepository officeRepo;
    private final ObjectMapper objectMapper; // [MỚI] Inject ObjectMapper để tự parse

    // [SỬA] Đổi tham số từ CompanyConfigEvent thành String message
    @RabbitListener(queues = RabbitMQConfig.QUEUE_ATTENDANCE_CONFIG)
    public void receiveCompanyConfig(String message) {
        try {
            log.info("--> [Attendance] Raw Message: {}", message);

            // 1. [MỚI] Xử lý chuỗi JSON (Clean chuỗi nếu bị bọc trong dấu ngoặc kép)
            String cleanJson = message;
            if (message.startsWith("\"") && message.endsWith("\"")) {
                // Nếu message là "{\"id\":1...}" thì bỏ ngoặc kép bao ngoài và unescape
                cleanJson = message.substring(1, message.length() - 1).replace("\\\"", "\"");
            }

            // 2. [MỚI] Parse từ String sang Object
            CompanyConfigEvent event = objectMapper.readValue(cleanJson, CompanyConfigEvent.class);
            
            log.info("--> [Attendance] Đang xử lý update cho Company ID: {}", event.getCompanyId());

            // 3. Logic lưu DB (Giữ nguyên như cũ)
            List<OfficeConfig> configs = officeRepo.findByCompanyId(event.getCompanyId());
            OfficeConfig config;

            if (configs.isEmpty()) {
                config = new OfficeConfig();
                config.setCompanyId(event.getCompanyId());
            } else {
                config = configs.get(0);
            }

            // Map dữ liệu
            config.setOfficeName(event.getOfficeName());
            config.setLatitude(event.getLatitude());
            config.setLongitude(event.getLongitude());
            config.setAllowedRadius(event.getAllowedRadius());
            config.setWifiBssid(event.getWifiBssid());
            config.setWifiSsid(event.getWifiSsid());

            // Lưu xuống DB
            officeRepo.save(config);
            log.info("--> Đã lưu cấu hình chấm công thành công!");

        } catch (Exception e) {
            log.error("Lỗi xử lý config event: {}", e.getMessage());
            e.printStackTrace(); // In stack trace để dễ debug nếu json sai format
        }
    }
}