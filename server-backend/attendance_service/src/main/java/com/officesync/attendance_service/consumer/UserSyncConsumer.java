package com.officesync.attendance_service.consumer;

import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper; // [THÊM IMPORT]
import com.officesync.attendance_service.config.RabbitMQConfig;
import com.officesync.attendance_service.dto.EmployeeSyncEvent;
import com.officesync.attendance_service.model.AttendanceUser;
import com.officesync.attendance_service.repository.AttendanceUserRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserSyncConsumer {

    private final AttendanceUserRepository userRepo;
    private final ObjectMapper objectMapper; // [ĐÃ CÓ KIỂU DỮ LIỆU]

    @RabbitListener(queues = RabbitMQConfig.QUEUE_USER_SYNC)
    public void receiveUserSync(String message) {
        try {
            // 1. Làm sạch chuỗi JSON nếu cần
            String cleanJson = message;
            if (message.startsWith("\"") && message.endsWith("\"")) {
                cleanJson = message.substring(1, message.length() - 1).replace("\\\"", "\"");
            }

            // 2. Chuyển đổi JSON sang DTO
            EmployeeSyncEvent event = objectMapper.readValue(cleanJson, EmployeeSyncEvent.class);

            // 3. Đồng bộ vào bảng User cục bộ (Snapshot)
            AttendanceUser user = new AttendanceUser();
            user.setId(event.getId());
            user.setFullName(event.getFullName());
            user.setEmail(event.getEmail());
            user.setPhone(event.getPhone());
            user.setDateOfBirth(event.getDateOfBirth());
            user.setCompanyId(event.getCompanyId());
            user.setRole(event.getRole());
            user.setDepartmentName(event.getDepartmentName());

            userRepo.save(user);
            log.info("--> [Attendance] User has been synchronized: {}", event.getEmail());

        } catch (Exception e) {
            log.error("User synchronization error in Attendance Service: {}", e.getMessage());
            e.printStackTrace();
        }
    }
}