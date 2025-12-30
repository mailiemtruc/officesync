package com.officesync.notification_service.controller;

import com.officesync.notification_service.model.Notification;
import com.officesync.notification_service.service.NotificationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    @Autowired
    private NotificationService notificationService;

    // API 1: App gọi cái này khi vừa đăng nhập để nộp Token
    // POST /api/notifications/register-device
    // Body: { "userId": 1, "token": "d8a7..." }
    @PostMapping("/register-device")
    public ResponseEntity<?> registerDevice(@RequestBody Map<String, Object> payload) {
        Long userId = Long.valueOf(payload.get("userId").toString());
        String token = (String) payload.get("token");

        notificationService.registerDevice(userId, token);
        return ResponseEntity.ok("Device registered successfully");
    }

    // API 2: Lấy danh sách thông báo
    // GET /api/notifications/user/1
    @GetMapping("/user/{userId}")
    public ResponseEntity<List<Notification>> getUserNotifications(@PathVariable Long userId) {
        return ResponseEntity.ok(notificationService.getUserNotifications(userId));
    }
    
    // API TEST: Dùng để test thử xem có nhận được thông báo không
    // POST /api/notifications/test-send
    @PostMapping("/test-send")
    public ResponseEntity<?> testSend(@RequestBody Map<String, Object> payload) {
        Long userId = Long.valueOf(payload.get("userId").toString());
        String title = (String) payload.get("title");
        String body = (String) payload.get("body");
        
        notificationService.sendNotification(userId, title, body, "TEST", 0L);
        return ResponseEntity.ok("Sent test notification");
    }
}