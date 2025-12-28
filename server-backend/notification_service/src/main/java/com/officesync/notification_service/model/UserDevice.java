package com.officesync.notification_service.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "user_devices")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserDevice {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId; // ID nhân viên

    @Column(nullable = false, length = 500)
    private String fcmToken; // Token của điện thoại
}