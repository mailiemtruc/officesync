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

import com.officesync.attendance_service.dto.DailyTimesheetDTO;
import com.officesync.attendance_service.model.Attendance;
import com.officesync.attendance_service.model.AttendanceUser;
import com.officesync.attendance_service.repository.AttendanceRepository;
import com.officesync.attendance_service.repository.AttendanceUserRepository;
import com.officesync.attendance_service.service.AttendanceService;

import lombok.Data;
import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/attendance")
@RequiredArgsConstructor
public class AttendanceController {

    private final AttendanceService attendanceService;
    private final AttendanceRepository attendanceRepo;
    private final AttendanceUserRepository userRepo;

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

    // --- API DÀNH CHO MANAGER ---
    @GetMapping("/manager/list")
    public ResponseEntity<?> getListForManager(
            @RequestHeader("X-User-Id") Long managerId, // ID người gọi API
            @RequestHeader("X-User-Role") String userRole,
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) Integer year
    ) {
        // 1. [BẢO MẬT] Chặn SUPER_ADMIN truy cập dữ liệu nghiệp vụ
        if ("SUPER_ADMIN".equals(userRole)) {
            return ResponseEntity.status(403)
                    .body(Map.of("error", "Super Admins are not permitted to view private company data."));
        }

        // 2. Xác định thời gian (Đầu tháng - Cuối tháng)
        if (month == null || year == null) {
            LocalDateTime now = LocalDateTime.now();
            month = now.getMonthValue();
            year = now.getYear();
        }
        YearMonth yearMonth = YearMonth.of(year, month);
        LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
        LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

        // 3. Lấy thông tin Manager để tìm CompanyID
        // Vì SUPER_ADMIN đã bị chặn ở trên, code chạy xuống đây chắc chắn là HR hoặc COMPANY_ADMIN
        AttendanceUser manager = userRepo.findById(managerId).orElse(null);

        if (manager == null) {
            return ResponseEntity.status(400)
                    .body(Map.of("error", "No management information was found in the timekeeping system."));
        }

        Long companyId = manager.getCompanyId();
        
        // Kiểm tra kỹ hơn: Nếu user có role quản lý nhưng lại không thuộc công ty nào
        if (companyId == null) {
             return ResponseEntity.status(400)
                    .body(Map.of("error", "This account has not been assigned to any company."));
        }

        // 4. Gọi Repository để lấy dữ liệu THEO COMPANY_ID
        // Đảm bảo bạn đã khai báo hàm này trong AttendanceRepository nhé
        List<Attendance> results = attendanceRepo.findByCompanyIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(
                companyId, start, end
        );

        return ResponseEntity.ok(results);
    }

    @GetMapping("/timesheet")
    public ResponseEntity<?> getMonthlyTimesheet(
            @RequestHeader("X-User-Id") Long userId, // Lấy ID từ Header (do Gateway truyền vào)
            @RequestParam(required = false) Integer month,
            @RequestParam(required = false) Integer year) {

        // Nếu không truyền tháng/năm thì lấy hiện tại
        if (month == null || year == null) {
            LocalDateTime now = LocalDateTime.now();
            month = now.getMonthValue();
            year = now.getYear();
        }

        try {
            List<DailyTimesheetDTO> result = attendanceService.generateMonthlyTimesheet(userId, month, year);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(e.getMessage());
        }
    }
}