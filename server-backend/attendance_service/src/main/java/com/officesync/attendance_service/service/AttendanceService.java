package com.officesync.attendance_service.service;

import com.officesync.attendance_service.model.Attendance;
import com.officesync.attendance_service.model.OfficeConfig;
import com.officesync.attendance_service.repository.AttendanceRepository;
import com.officesync.attendance_service.repository.OfficeConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceService {

    private final AttendanceRepository attendanceRepo;
    private final OfficeConfigRepository officeConfigRepo;

    // Hàm xử lý Check-in chính
    public Attendance processCheckIn(Long userId, Double lat, Double lng, String bssid) {
        // [Giả định] Vì service này tách biệt, ta tạm lấy config của Company ID = 2 (FPT)
        // Trong thực tế: Bạn có thể gọi API sang Core để lấy companyId của user này.
        Long companyId = 2L;

        // 1. Lấy danh sách văn phòng
        List<OfficeConfig> offices = officeConfigRepo.findByCompanyId(companyId);
        if (offices.isEmpty()) {
            throw new RuntimeException("Hệ thống chưa cấu hình vị trí văn phòng!");
        }

        boolean isValid = false;
        String matchedLocation = "Unknown";

        // 2. So khớp vị trí & Wifi
        for (OfficeConfig office : offices) {
            log.info("Checking office: {} | Setup BSSID: {}", office.getOfficeName(), office.getWifiBssid());
            log.info("Client BSSID: {}", bssid);

            // A. Check Wifi (BSSID) - Không phân biệt hoa thường
            boolean isWifiMatch = false;
            if (office.getWifiBssid() != null && bssid != null) {
                // Loại bỏ dấu hai chấm nếu có để so sánh chuẩn hơn (tùy định dạng)
                String cleanServerBssid = office.getWifiBssid().replace(":", "").toLowerCase();
                String cleanClientBssid = bssid.replace(":", "").toLowerCase();

                if (cleanClientBssid.equals(cleanServerBssid)) {
                    isWifiMatch = true;
                }
            }

            // B. Check GPS (Khoảng cách)
            double distance = calculateHaversineDistance(lat, lng, office.getLatitude(), office.getLongitude());
            log.info("Distance to {}: {} meters", office.getOfficeName(), distance);

            boolean isGpsMatch = distance <= office.getAllowedRadius();

            // C. Quyết định: Cần CẢ HAI hoặc MỘT TRONG HAI?
            // Ở đây tôi để logic: Phải đúng WIFI và gần đúng GPS (Bảo mật cao)
            if (isWifiMatch && isGpsMatch) {
                isValid = true;
                matchedLocation = office.getOfficeName();
                break;
            }

            // Nếu muốn nới lỏng: Chỉ cần đúng Wifi là được (vì Wifi khó fake hơn GPS)
            // if (isWifiMatch) { isValid = true; matchedLocation = office.getOfficeName(); break; }
        }

        if (!isValid) {
            throw new RuntimeException("Check-in thất bại: Bạn không ở văn phòng hoặc sai Wifi công ty.");
        }

        // 3. Lưu lại
        Attendance att = new Attendance();
        att.setUserId(userId);
        att.setCompanyId(companyId);
        att.setCheckInTime(LocalDateTime.now());
        att.setLocationName(matchedLocation);
        att.setDeviceBssid(bssid);
        att.setStatus("ON_TIME"); // Logic tính muộn làm sau

        return attendanceRepo.save(att);
    }

    // Công thức tính khoảng cách giữa 2 tọa độ (Trả về mét)
    private double calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Bán kính trái đất (km)
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c * 1000; // Đổi ra mét
    }
}
