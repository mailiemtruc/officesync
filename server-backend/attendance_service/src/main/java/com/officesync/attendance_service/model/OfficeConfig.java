package com.officesync.attendance_service.model;

import java.time.LocalTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "office_configs")
@Data
public class OfficeConfig {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long companyId; // ID công ty (để phân biệt nếu hệ thống Multi-tenant)

    @Column(nullable = false)
    private String officeName; // VD: Trụ sở Hà Nội

    // --- CẤU HÌNH GPS ---
    private Double latitude;
    private Double longitude;
    private Double allowedRadius; // Bán kính cho phép (mét), VD: 100.0

    // --- CẤU HÌNH WIFI ---
    private String wifiBssid; // Địa chỉ MAC của Router (Quan trọng)
    private String wifiSsid;  // Tên Wifi (Để hiển thị cho dễ nhớ)

    @Column(name = "start_work_time")
    private LocalTime startWorkTime;

    @Column(name = "end_work_time")
    private LocalTime endWorkTime;
}