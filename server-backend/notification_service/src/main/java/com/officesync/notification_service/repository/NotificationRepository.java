package com.officesync.notification_service.repository;

import com.officesync.notification_service.model.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    // Lấy list thông báo của user, mới nhất lên đầu
    List<Notification> findByUserIdOrderByCreatedAtDesc(Long userId);
}