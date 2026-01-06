package com.officesync.attendance_service.model;

import java.time.LocalDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "attendances")
@Data
public class Attendance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    private Long companyId;

    @Column(nullable = false)
    private LocalDateTime checkInTime;

    private String locationName; // Tên văn phòng lúc check-in
    private String deviceBssid;  // BSSID của thiết bị lúc check-in
    private String status;       // ON_TIME, LATE...
}
