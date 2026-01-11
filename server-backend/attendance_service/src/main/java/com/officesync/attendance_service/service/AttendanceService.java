package com.officesync.attendance_service.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.officesync.attendance_service.dto.DailyTimesheetDTO;
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
        
        // --- 1. XÁC ĐỊNH LOẠI CHẤM CÔNG (IN hay OUT) ---
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        LocalDateTime endOfDay = LocalDate.now().atTime(LocalTime.MAX);

        // Lấy danh sách chấm công hôm nay (Mới nhất lên đầu)
        List<Attendance> todayRecords = attendanceRepo.findByUserIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(
                userId, startOfDay, endOfDay
        );

        String attendanceType;
        if (todayRecords.isEmpty()) {
            attendanceType = "CHECK_IN"; // Chưa có record nào -> Là Check-in
        } else {
            Attendance lastRecord = todayRecords.get(0);
            if ("CHECK_IN".equals(lastRecord.getType())) {
                attendanceType = "CHECK_OUT"; // Trước đó là In -> Giờ là Out
            } else {
                attendanceType = "CHECK_IN";  // Trước đó là Out -> Giờ vào lại
            }

            // Chặn spam Check-out quá nhanh (< 1 phút)
            if ("CHECK_OUT".equals(attendanceType) && 
                java.time.Duration.between(lastRecord.getCheckInTime(), LocalDateTime.now()).toMinutes() < 1) {
                throw new RuntimeException("You have just checked in, please wait a little longer before checking out.");
            }
        }

        // --- 2. KIỂM TRA VỊ TRÍ & WIFI ---
        List<OfficeConfig> offices = officeConfigRepo.findByCompanyId(companyId);
        if (offices.isEmpty()) {
            throw new RuntimeException("The company hasn't configured the timekeeping location yet!");
        }

        boolean isValid = false;
        String matchedLocation = "Unknown";
        OfficeConfig matchedOffice = null; // [QUAN TRỌNG] Lưu lại config khớp để lấy giờ làm việc

        for (OfficeConfig office : offices) {
            // --- 2.1 Check Wifi ---
            // Kiểm tra xem công ty có cấu hình Wifi hay không
            boolean isWifiConfigured = office.getWifiBssid() != null && !office.getWifiBssid().isEmpty();
            boolean isWifiMatch = false;

            if (isWifiConfigured) {
                // Nếu có cấu hình Wifi, so sánh BSSID (nếu user có gửi lên)
                if (bssid != null) {
                    String cleanServerBssid = office.getWifiBssid().replace(":", "").toLowerCase();
                    String cleanClientBssid = bssid.replace(":", "").toLowerCase();
                    if (cleanClientBssid.equals(cleanServerBssid)) {
                        isWifiMatch = true;
                    }
                }
                // Lưu ý: Nếu bssid == null hoặc khác nhau -> isWifiMatch vẫn là false
            }

            // --- 2.2 Check GPS (Haversine) ---
            double distance = calculateHaversineDistance(lat, lng, office.getLatitude(), office.getLongitude());
            boolean isGpsMatch = distance <= office.getAllowedRadius();

            // --- 2.3 Logic Tổng Hợp (QUAN TRỌNG: SỬA TẠI ĐÂY) ---
            // Điều kiện chấm công thành công:
            // 1. GPS bắt buộc phải đúng.
            // 2. VÀ: (Hoặc là công ty KHÔNG cấu hình Wifi, Hoặc là nếu có cấu hình thì phải khớp).
            
            if (isGpsMatch && (!isWifiConfigured || isWifiMatch)) { 
                isValid = true;
                matchedLocation = office.getOfficeName();
                matchedOffice = office; // Lưu lại để tính giờ
                break;
            }
        }

        if (!isValid) {
            throw new RuntimeException("Check-in failed: Invalid location.");
        }

        // --- 3. [MỚI] TÍNH TOÁN TRẠNG THÁI (LATE / ON_TIME) ---
        LocalDateTime now = LocalDateTime.now();
        LocalTime timeNow = now.toLocalTime();
        
        String status = "ON_TIME";
        Integer lateMinutes = 0;

        // Chỉ tính đi muộn nếu đây là CHECK_IN
        if ("CHECK_IN".equals(attendanceType) && matchedOffice != null && matchedOffice.getStartWorkTime() != null) {
            LocalTime startWorkTime = matchedOffice.getStartWorkTime();
            
            // Cho phép trễ X phút (Grace Period), ví dụ 0 phút
            // Nếu giờ hiện tại > giờ quy định
            if (timeNow.isAfter(startWorkTime)) {
                status = "LATE";
                // Tính số phút chênh lệch
                lateMinutes = (int) java.time.temporal.ChronoUnit.MINUTES.between(startWorkTime, timeNow);
            }
        }
        
        // (Mở rộng) Nếu CHECK_OUT, có thể tính về sớm (EARLY_LEAVE) nếu cần
        // if ("CHECK_OUT".equals(attendanceType) ... )

        // --- 4. LƯU ATTENDANCE ---
        Attendance att = new Attendance();
        att.setUserId(userId);
        att.setCompanyId(companyId);
        
        AttendanceUser user = userRepo.findById(userId).orElse(null);
        if (user != null) {
            att.setFullName(user.getFullName());
            att.setEmail(user.getEmail());
            att.setPhone(user.getPhone());
            att.setDateOfBirth(user.getDateOfBirth());
            att.setRole(user.getRole());                    
            att.setDepartmentName(user.getDepartmentName());
        } else {
            att.setFullName("Unknown User");
            att.setRole("UNKNOWN");
        }

        att.setCheckInTime(now);
        att.setLocationName(matchedLocation);
        att.setDeviceBssid(bssid);
        att.setType(attendanceType);
        
        // Set thông tin trạng thái mới tính toán
        att.setStatus(status);        
        att.setLateMinutes(lateMinutes); 

        return attendanceRepo.save(att);
    }

    // Hàm phụ tính khoảng cách (Giữ nguyên nếu bạn đã có)
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

    public List<DailyTimesheetDTO> generateMonthlyTimesheet(Long userId, int month, int year) {
        YearMonth yearMonth = YearMonth.of(year, month);
        LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
        LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

        // 1. Lấy logs
        List<Attendance> logs = attendanceRepo.findByUserIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(userId, start, end);

        // 2. Group logs
        Map<LocalDate, List<Attendance>> groupedByDay = logs.stream()
                .collect(Collectors.groupingBy(log -> log.getCheckInTime().toLocalDate()));

        List<DailyTimesheetDTO> timesheet = new ArrayList<>();
        LocalDate today = LocalDate.now(); // [MỚI] Lấy ngày hiện tại

        // 3. Duyệt từng ngày
        for (int day = 1; day <= yearMonth.lengthOfMonth(); day++) {
            LocalDate currentDate = yearMonth.atDay(day);
            
            // --- CASE 1: KHÔNG CÓ DỮ LIỆU ---
            if (!groupedByDay.containsKey(currentDate)) {
                // Nếu là ngày tương lai -> Bỏ qua hoặc để null (tùy logic hiển thị)
                if (currentDate.isAfter(today)) {
                     continue; 
                }
                
                timesheet.add(DailyTimesheetDTO.builder()
                        .date(currentDate)
                        .totalWorkingHours(0)
                        .status("ABSENT") 
                        .sessions(new ArrayList<>())
                        .build());
                continue;
            }

            // --- CASE 2: CÓ DỮ LIỆU (ĐI LÀM) ---
            List<Attendance> dailyLogs = groupedByDay.get(currentDate);
            dailyLogs.sort(Comparator.comparing(Attendance::getCheckInTime));

            List<DailyTimesheetDTO.Session> sessions = new ArrayList<>();
            double totalHours = 0;
            boolean isMissingCheckout = false;
            
            Attendance tempIn = null;

            for (Attendance log : dailyLogs) {
                if ("CHECK_IN".equals(log.getType())) {
                    if (tempIn != null) {
                        // Có IN rồi mà lại gặp IN tiếp -> Quên Checkout lần trước
                        isMissingCheckout = true;
                    }
                    tempIn = log; 
                } 
                else if ("CHECK_OUT".equals(log.getType())) {
                    if (tempIn != null) {
                        // Ghép cặp thành công
                        double duration = java.time.Duration.between(tempIn.getCheckInTime(), log.getCheckInTime()).toMinutes() / 60.0;
                        
                        sessions.add(new DailyTimesheetDTO.Session(
                            tempIn.getCheckInTime().toLocalTime(),
                            log.getCheckInTime().toLocalTime(),
                            Math.round(duration * 100.0) / 100.0
                        ));
                        
                        totalHours += duration;
                        tempIn = null; 
                    }
                }
            }

            // --- [ĐOẠN ĐÃ SỬA] XỬ LÝ CHECK-IN CUỐI CÙNG ---
            String status = "OK"; // Mặc định là OK

            if (tempIn != null) {
                // Vẫn còn dư 1 lượt Check-in chưa đóng
                
                // Kiểm tra xem có phải hôm nay không?
                if (currentDate.isEqual(today)) {
                    // LÀ HÔM NAY -> ĐANG LÀM VIỆC (Không phải lỗi)
                    status = "WORKING";
                    
                    // Vẫn hiển thị session mở (giờ vào, giờ ra null)
                    sessions.add(new DailyTimesheetDTO.Session(
                            tempIn.getCheckInTime().toLocalTime(),
                            null, 
                            0
                    ));
                } else {
                    // LÀ NGÀY QUÁ KHỨ -> QUÊN CHECKOUT (Lỗi)
                    isMissingCheckout = true;
                    status = "MISSING_CHECKOUT";
                    
                    sessions.add(new DailyTimesheetDTO.Session(
                            tempIn.getCheckInTime().toLocalTime(),
                            null, 
                            0
                    ));
                }
            } else {
                // tempIn == null (đã ghép cặp hết), nhưng trước đó có cờ lỗi (ví dụ 2 lần IN liên tiếp)
                if (isMissingCheckout) {
                    status = "MISSING_CHECKOUT";
                }
            }

            // Build DTO
            timesheet.add(DailyTimesheetDTO.builder()
                    .date(currentDate)
                    .totalWorkingHours(Math.round(totalHours * 100.0) / 100.0)
                    .status(status) // Sử dụng status đã tính toán kỹ ở trên
                    .sessions(sessions)
                    .build());
        }

        return timesheet;
    }
}