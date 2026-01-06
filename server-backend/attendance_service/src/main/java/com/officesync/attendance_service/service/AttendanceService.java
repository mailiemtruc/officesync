package com.officesync.attendance_service.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

import org.springframework.stereotype.Service;

import com.officesync.attendance_service.model.Attendance;
import com.officesync.attendance_service.model.AttendanceUser;
import com.officesync.attendance_service.model.OfficeConfig;
import com.officesync.attendance_service.repository.AttendanceRepository;
import com.officesync.attendance_service.repository.AttendanceUserRepository;
import com.officesync.attendance_service.repository.OfficeConfigRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class AttendanceService {

    private final AttendanceRepository attendanceRepo;
    private final OfficeConfigRepository officeConfigRepo;
    private final AttendanceUserRepository userRepo;

    public Attendance processCheckIn(Long userId, Long companyId, Double lat, Double lng, String bssid) {
        
        // --- 1. KIỂM TRA SỐ LẦN CHẤM CÔNG HÔM NAY ---
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay(); // 00:00:00 hôm nay
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX); // 23:59:59 hôm nay

        List<Attendance> todayRecords = attendanceRepo.findByUserIdAndCheckInTimeBetween(userId, startOfDay, endOfDay);

        if (todayRecords.size() >= 2) {
            throw new RuntimeException("You have completed your timekeeping for today (Entry/Exit counts are sufficient).");
        }

        // Xác định loại chấm công:
        // - Nếu chưa có bản ghi nào -> CHECK_IN
        // - Nếu đã có 1 bản ghi -> CHECK_OUT
        String attendanceType = todayRecords.isEmpty() ? "CHECK_IN" : "CHECK_OUT";

        // --- 2. LOGIC KIỂM TRA VỊ TRÍ & WIFI (GIỮ NGUYÊN) ---
        List<OfficeConfig> offices = officeConfigRepo.findByCompanyId(companyId);
        if (offices.isEmpty()) {
            throw new RuntimeException("The company hasn't configured the office location yet!");
        }

        boolean isValid = false;
        String matchedLocation = "Unknown";

        for (OfficeConfig office : offices) {
            boolean isWifiMatch = false;
            if (office.getWifiBssid() != null && bssid != null) {
                String cleanServerBssid = office.getWifiBssid().replace(":", "").toLowerCase();
                String cleanClientBssid = bssid.replace(":", "").toLowerCase();
                if (cleanClientBssid.equals(cleanServerBssid)) isWifiMatch = true;
            }

            double distance = calculateHaversineDistance(lat, lng, office.getLatitude(), office.getLongitude());
            boolean isGpsMatch = distance <= office.getAllowedRadius();

            if (isWifiMatch && isGpsMatch) {
                isValid = true;
                matchedLocation = office.getOfficeName();
                break;
            }
        }

        if (!isValid) {
            throw new RuntimeException("Check-in failed: Incorrect location or Wi-Fi network.");
        }

        // --- 3. LƯU LẠI ---
        Attendance att = new Attendance();
        att.setUserId(userId);
        att.setCompanyId(companyId);
        
        // [MỚI] LẤY THÔNG TIN USER VÀ LƯU (Snapshot data)
        AttendanceUser user = userRepo.findById(userId).orElse(null);
        if (user != null) {
            att.setFullName(user.getFullName());
            att.setEmail(user.getEmail());
            att.setPhone(user.getPhone());
            att.setDateOfBirth(user.getDateOfBirth());
            att.setRole(user.getRole());                     
            att.setDepartmentName(user.getDepartmentName());
        } else {
            // Fallback nếu chưa đồng bộ kịp (Tránh lỗi null)
            att.setFullName("Unknown");
            att.setRole("UNKNOWN");
            att.setDepartmentName("UNKNOWN");
        }

        att.setCheckInTime(LocalDateTime.now());
        att.setLocationName(matchedLocation);
        att.setDeviceBssid(bssid);
        att.setType(attendanceType); 
        att.setStatus("ON_TIME"); 

        return attendanceRepo.save(att);
    }
    

    private double calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; 
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c * 1000; 
    }
}