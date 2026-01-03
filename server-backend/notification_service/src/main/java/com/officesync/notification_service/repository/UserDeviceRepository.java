package com.officesync.notification_service.repository;

import com.officesync.notification_service.model.UserDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserDeviceRepository extends JpaRepository<UserDevice, Long> {
    Optional<UserDevice> findByUserId(Long userId);
    Optional<UserDevice> findByFcmToken(String fcmToken);
    // 👇 THÊM DÒNG NÀY VÀO ĐÂY:
    void deleteByUserId(Long userId);
}