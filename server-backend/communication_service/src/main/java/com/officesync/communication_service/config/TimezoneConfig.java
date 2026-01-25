package com.officesync.communication_service.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import java.util.TimeZone;

@Configuration
public class TimezoneConfig {

    @PostConstruct
    public void init() {
        // Ép toàn bộ Service chạy theo múi giờ Hồ Chí Minh (GMT+7)
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        System.out.println("--> [Config] Đã thiết lập múi giờ: Asia/Ho_Chi_Minh (GMT+7)");
    }
}