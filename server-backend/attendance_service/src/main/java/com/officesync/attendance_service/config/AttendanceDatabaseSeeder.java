package com.officesync.attendance_service.config;

import com.officesync.attendance_service.model.OfficeConfig;
import com.officesync.attendance_service.repository.OfficeConfigRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AttendanceDatabaseSeeder {

    @Bean
    CommandLineRunner initDatabase(OfficeConfigRepository repo) {
        return args -> {
            if (repo.count() == 0) {
                OfficeConfig office = new OfficeConfig();
                office.setCompanyId(2L); // ID công ty FPT (Ví dụ)
                office.setOfficeName("FPT Tower Test");
                
                // [QUAN TRỌNG] Bạn hãy sửa lại tọa độ này thành nơi bạn đang ngồi để test
                office.setLatitude(10.792367);  // Ví dụ: Tọa độ TP.HCM
                office.setLongitude(106.696145);
                office.setAllowedRadius(200.0); // Cho phép sai số 200m
                
                // [RẤT QUAN TRỌNG] Thay chuỗi này bằng BSSID thật của wifi nhà bạn
                // Bạn có thể xem BSSID trên Mobile App ở màn hình AttendanceScreen vừa code
                office.setWifiBssid("02:00:00:00:00:00"); // Ví dụ: b0:a7:b9:xx:xx:xx
                office.setWifiSsid("Wifi Nha Toi");
                
                repo.save(office);
                System.out.println("--> Đã tạo dữ liệu cấu hình văn phòng mẫu!");
            }
        };
    }
}