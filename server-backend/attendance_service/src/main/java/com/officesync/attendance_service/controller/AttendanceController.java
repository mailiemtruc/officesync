package com.officesync.attendance_service.controller;

import com.officesync.attendance_service.model.Attendance;
import com.officesync.attendance_service.service.AttendanceService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/attendance")
@RequiredArgsConstructor
public class AttendanceController {

    private final AttendanceService attendanceService;

    // DTO hứng dữ liệu từ Mobile gửi lên
    @Data
    public static class CheckInRequest {
        private Double latitude;
        private Double longitude;
        private String bssid; // Địa chỉ MAC wifi
    }

    @PostMapping("/check-in")
    public ResponseEntity<?> checkIn(
            @RequestHeader("X-User-Id") Long userId, // Lấy ID user từ Header (Do ApiClient Mobile gửi)
            @RequestBody CheckInRequest request
    ) {
        try {
            // Validate dữ liệu
            if (request.getLatitude() == null || request.getLongitude() == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Thiếu tọa độ GPS"));
            }
            if (request.getBssid() == null || request.getBssid().isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Không lấy được thông tin Wifi"));
            }

            Attendance result = attendanceService.processCheckIn(
                    userId,
                    request.getLatitude(),
                    request.getLongitude(),
                    request.getBssid()
            );
            return ResponseEntity.ok(result);

        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}