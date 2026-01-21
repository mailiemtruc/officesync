package com.officesync.core.service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.officesync.core.dto.CompanyConfigEvent;
import com.officesync.core.model.Company;
import com.officesync.core.model.SystemDailyStat;
import com.officesync.core.repository.CompanyRepository;
import com.officesync.core.repository.SystemDailyStatRepository;
import com.officesync.core.repository.UserRepository;

@Service
public class CompanyService {

    @Autowired private CompanyRepository companyRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private RabbitMQProducer rabbitProducer;
    @Autowired private SystemDailyStatRepository statRepository;
    @Autowired private SecurityNotificationService securitySocket;

    // --- Cho Admin ---
    public Map<String, Object> getSystemStats() {
        Map<String, Object> stats = new HashMap<>();
        
        // Lấy số liệu hiện tại (Realtime)
        long currentUsers = userRepository.count();
        long currentCompanies = companyRepository.count();

        stats.put("companies", currentCompanies);
        stats.put("users", currentUsers);

        // 2. Lấy lịch sử từ DB (Real History)
        List<SystemDailyStat> historyStats = statRepository.findTop7ByOrderByDateDesc();
        
        // Chuyển đổi List<Entity> thành List<Long> (chỉ lấy số lượng user để vẽ chart)
        // Đảo ngược list để sắp xếp từ cũ đến mới (Ngày 1 -> Ngày 7)
        List<Long> chartData = historyStats.stream()
            .map(SystemDailyStat::getTotalUsers)
            .sorted() // Sắp xếp lại nếu cần, hoặc dùng Collections.reverse
            .collect(Collectors.toList());

        // Nếu hệ thống mới tinh chưa có lịch sử, thêm số hiện tại vào để chart không bị trống
        if (chartData.isEmpty()) {
            chartData.add(currentUsers);
        }

        stats.put("history", chartData); // Trả về mảng thật

        return stats;
    }

    public List<Company> getAllCompanies() {
        return companyRepository.findAll();
    }

    public Company getCompanyDetail(Long id) {
        return companyRepository.findById(id).orElseThrow(() -> new RuntimeException("Company not found"));
    }

    public void updateCompanyStatus(Long id, String status) {
        Company company = getCompanyDetail(id);
        company.setStatus(status);
        
        // 1. Lưu vào Database
        companyRepository.save(company);

        // 2. Bắn RabbitMQ (Tuỳ chọn - Để đồng bộ với các service backend khác như HR)
        /* try {
            CompanyStatusChangedEvent event = new CompanyStatusChangedEvent(id, status);
            rabbitProducer.sendCompanyStatusChangedEvent(event);
        } catch (Exception e) {
            System.err.println("Lỗi gửi RabbitMQ Status Change: " + e.getMessage());
        }
        */

        // 🔴 3. [THÊM MỚI] Bắn Socket trực tiếp xuống Mobile App
        // Nếu trạng thái là LOCKED -> Đá văng toàn bộ nhân viên công ty ra
        if ("LOCKED".equals(status)) {
            try {
                securitySocket.notifyCompanyLocked(id);
                System.out.println("--> Đã gửi lệnh KHOÁ CÔNG TY qua WebSocket cho Company ID: " + id);
            } catch (Exception e) {
                System.err.println("Lỗi gửi WebSocket notification: " + e.getMessage());
            }
        }
    }

    public List<Map<String, Object>> getTopCompanies() {
        List<Company> allCompanies = companyRepository.findAll();
        List<Map<String, Object>> result = new ArrayList<>();

        for (Company c : allCompanies) {
            long userCount = userRepository.countByCompanyId(c.getId());
            Map<String, Object> map = new HashMap<>();
            map.put("id", c.getId());
            map.put("name", c.getName());
            map.put("domain", c.getDomain());
            map.put("status", c.getStatus());
            map.put("userCount", userCount);
            map.put("logoUrl", c.getLogoUrl()); // Thêm logo nếu cần
            map.put("industry", c.getIndustry());
            result.add(map);
        }

        return result.stream()
                .sorted((c1, c2) -> Long.compare((long)c2.get("userCount"), (long)c1.get("userCount")))
                .limit(3)
                .collect(Collectors.toList());
    }

    // --- Cho Company Admin ---
    public Company getMyCompany(Long companyId) {
        if (companyId == null) throw new RuntimeException("User not in company");
        return companyRepository.findById(companyId).orElseThrow(() -> new RuntimeException("Company not found"));
    }

    // Tìm đến hàm updateMyCompany và thay thế bằng đoạn này:
    public Company updateMyCompany(Long companyId, Map<String, Object> req) {
        Company company = companyRepository.findById(companyId)
                .orElseThrow(() -> new RuntimeException("Company not found"));

        // 1. Cập nhật thông tin cơ bản
        if (req.containsKey("name")) company.setName((String) req.get("name"));
        if (req.containsKey("industry")) company.setIndustry((String) req.get("industry"));
        if (req.containsKey("description")) company.setDescription((String) req.get("description"));
        if (req.containsKey("logoUrl")) company.setLogoUrl((String) req.get("logoUrl"));

        // 2. Cập nhật cấu hình GPS/Wifi
        if (req.containsKey("latitude") && req.get("latitude") != null) {
            company.setLatitude(Double.valueOf(req.get("latitude").toString()));
        }
        if (req.containsKey("longitude") && req.get("longitude") != null) {
            company.setLongitude(Double.valueOf(req.get("longitude").toString()));
        }
        if (req.containsKey("allowedRadius") && req.get("allowedRadius") != null) {
            company.setAllowedRadius(Double.valueOf(req.get("allowedRadius").toString()));
        }
        if (req.containsKey("wifiBssid")) company.setWifiBssid((String) req.get("wifiBssid"));
        if (req.containsKey("wifiSsid")) company.setWifiSsid((String) req.get("wifiSsid"));

        // 3. [THÊM MỚI] Cập nhật Giờ làm việc (Parse từ String "08:00")
        if (req.containsKey("workStartTime")) {
            String startStr = (String) req.get("workStartTime");
            if (startStr != null && !startStr.isEmpty()) {
                company.setWorkStartTime(java.time.LocalTime.parse(startStr));
            }
        }
        if (req.containsKey("workEndTime")) {
            String endStr = (String) req.get("workEndTime");
            if (endStr != null && !endStr.isEmpty()) {
                company.setWorkEndTime(java.time.LocalTime.parse(endStr));
            }
        }

        // 4. Lưu vào Database Core
        Company updated = companyRepository.save(company);

        // 5. Bắn Event sang Attendance Service
        try {
            CompanyConfigEvent event = new CompanyConfigEvent(
                updated.getId(),
                updated.getName() + " - HQ",
                updated.getLatitude(),
                updated.getLongitude(),
                updated.getAllowedRadius() != null ? updated.getAllowedRadius() : 100.0,
                updated.getWifiBssid(),
                updated.getWifiSsid(),
                // [MỚI] Truyền giờ đi
                updated.getWorkStartTime(),
                updated.getWorkEndTime()
            );
            rabbitProducer.sendCompanyConfigEvent(event);
        } catch (Exception e) {
            System.err.println("Lỗi gửi RabbitMQ: " + e.getMessage());
        }

        return updated;
    }
}