package com.officesync.attendance_service.controller;

import java.time.LocalDateTime; // [MỚI]
import java.time.YearMonth;     // [MỚI] Để tính ngày đầu/cuối tháng
import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam; // [MỚI]
import org.springframework.web.bind.annotation.RestController;

import com.officesync.attendance_service.model.Attendance;
import com.officesync.attendance_service.repository.AttendanceRepository;
import com.officesync.attendance_service.service.AttendanceService;

import lombok.Data;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/attendance")
@RequiredArgsConstructor
public class AttendanceController {

    private final AttendanceService attendanceService;
    private final AttendanceRepository attendanceRepo;

    @Data
    public static class CheckInRequest {
        private Long companyId;
        private Double latitude;
        private Double longitude;
        private String bssid; 
    }

    // API 1: Chấm công (POST)
    @PostMapping("/check-in")
    public ResponseEntity<?> checkIn(
            @RequestHeader("X-User-Id") Long userId, 
            @RequestBody CheckInRequest request
    ) {
        try {
            if (request.getCompanyId() == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Company ID information is missing"));
            }
            if (request.getLatitude() == null || request.getLongitude() == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "Missing GPS coordinates"));
            }
            if (request.getBssid() == null || request.getBssid().isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("error", "Cannot retrieve Wifi information"));
            }

            Attendance result = attendanceService.processCheckIn(
                    userId,
                    request.getCompanyId(),
                    request.getLatitude(),
                    request.getLongitude(),
                    request.getBssid()
            );
            return ResponseEntity.ok(result);

        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    // API 2: Lấy lịch sử chấm công (GET) - Có lọc theo tháng/năm
    // Mobile gọi: GET /api/attendance/history?month=1&year=2026
    @GetMapping("/history")
    public ResponseEntity<List<Attendance>> getHistory(
            @RequestHeader("X-User-Id") Long userId,
            @RequestParam(required = false) Integer month, // [MỚI] Nhận tháng
            @RequestParam(required = false) Integer year   // [MỚI] Nhận năm
    ) {
        // 1. Nếu không truyền, mặc định lấy tháng hiện tại
        if (month == null || year == null) {
            LocalDateTime now = LocalDateTime.now();
            month = now.getMonthValue();
            year = now.getYear();
        }

        // 2. Tính toán ngày bắt đầu (ngày 1) và ngày kết thúc tháng
        YearMonth yearMonth = YearMonth.of(year, month);
        LocalDateTime startOfMonth = yearMonth.atDay(1).atStartOfDay(); // 00:00:00 ngày 1
        LocalDateTime endOfMonth = yearMonth.atEndOfMonth().atTime(23, 59, 59); // 23:59:59 ngày cuối

        // 3. Gọi Repo lấy dữ liệu trong khoảng này
        List<Attendance> history = attendanceRepo.findByUserIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(
                userId, startOfMonth, endOfMonth
        );
        
        return ResponseEntity.ok(history);
    }

    // API 3: [MỚI] Quản lý xem bảng công tổng hợp
    @GetMapping("/manager/list")
    public ResponseEntity<?> getAllAttendanceForManager(
            @RequestHeader("X-User-Role") String userRole, // Lấy Role từ Header
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) Integer year
    ) {
        // 1. [SỬA ĐOẠN NÀY] KIỂM TRA QUYỀN CHẶT CHẼ HƠN
        // Thay vì "MANAGER", ta yêu cầu "HR_MANAGER" (Quyền ảo do Client gửi lên sau khi đã check Main HR)
        // Các quyền cấp cao như COMPANY_ADMIN, SUPER_ADMIN vẫn giữ nguyên.
        if (!"COMPANY_ADMIN".equals(userRole) && 
            !"HR_MANAGER".equals(userRole) && // <--- ĐỔI TỪ MANAGER THÀNH HR_MANAGER
            !"SUPER_ADMIN".equals(userRole)) {
            
            return ResponseEntity.status(403).body(Map.of("error", "You do not have permission to access this data!"));
        }

        // 2. Xử lý thời gian (Giữ nguyên code cũ)
        if (month == null || year == null) {
            LocalDateTime now = LocalDateTime.now();
            month = now.getMonthValue();
            year = now.getYear();
        }

        YearMonth yearMonth = YearMonth.of(year, month);
        LocalDateTime startOfMonth = yearMonth.atDay(1).atStartOfDay();
        LocalDateTime endOfMonth = yearMonth.atEndOfMonth().atTime(23, 59, 59);

        // 3. Gọi Repo lấy tất cả (Giữ nguyên code cũ)
        List<Attendance> allRecords = attendanceRepo.findByCheckInTimeBetweenOrderByCheckInTimeDesc(startOfMonth, endOfMonth);
        
        return ResponseEntity.ok(allRecords);
    }
}