package com.officesync.notification_service.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification; // Lưu ý import của Firebase
import com.officesync.notification_service.model.UserDevice;
import com.officesync.notification_service.repository.NotificationRepository;
import com.officesync.notification_service.repository.UserDeviceRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class NotificationService {

    @Autowired
    private UserDeviceRepository deviceRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    // 1. Lưu Token của thiết bị (Khi User đăng nhập App)
    public void registerDevice(Long userId, String token) {
        // Kiểm tra xem user này đã có token trong DB chưa
        Optional<UserDevice> existingDevice = deviceRepository.findByUserId(userId);

        if (existingDevice.isPresent()) {
            // Nếu có rồi thì update token mới (phòng khi đổi máy)
            UserDevice device = existingDevice.get();
            device.setFcmToken(token);
            deviceRepository.save(device);
        } else {
            // Chưa có thì tạo mới
            UserDevice newDevice = new UserDevice();
            newDevice.setUserId(userId);
            newDevice.setFcmToken(token);
            deviceRepository.save(newDevice);
        }
    }

    // 2. Lấy danh sách thông báo lịch sử
    public List<com.officesync.notification_service.model.Notification> getUserNotifications(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    // 3. Gửi thông báo (Hàm này sẽ được gọi bởi RabbitMQ sau này)
    public void sendNotification(Long userId, String title, String body, String type, Long referenceId) {
        // B1: Lưu vào lịch sử database
        com.officesync.notification_service.model.Notification noti = new com.officesync.notification_service.model.Notification();
        noti.setUserId(userId);
        noti.setTitle(title);
        noti.setBody(body);
        noti.setType(type);
        noti.setReferenceId(referenceId);
        notificationRepository.save(noti);

        // B2: Tìm thiết bị của user để bắn Push
        Optional<UserDevice> deviceOpt = deviceRepository.findByUserId(userId);
        if (deviceOpt.isPresent()) {
            String token = deviceOpt.get().getFcmToken();
            try {
                // Tạo message gửi sang Firebase
                Message message = Message.builder()
                        .setToken(token)
                        .setNotification(Notification.builder()
                                .setTitle(title)
                                .setBody(body)
                                .build())
                        .putData("type", type) // Gửi kèm dữ liệu ẩn để App xử lý click
                        .putData("referenceId", String.valueOf(referenceId))
                        .build();

                // Gửi ngay lập tức
                FirebaseMessaging.getInstance().send(message);
                System.out.println("--> Đã gửi FCM tới user " + userId);
            } catch (Exception e) {
                System.err.println("Lỗi gửi Firebase: " + e.getMessage());
            }
        }
    }
}