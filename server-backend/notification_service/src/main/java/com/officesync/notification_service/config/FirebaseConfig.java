package com.officesync.notification_service.config;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;

import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;

import jakarta.annotation.PostConstruct;

@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void initialize() {
        try {
            // Kiểm tra xem Firebase đã được khởi tạo chưa để tránh lỗi duplicate
            if (!FirebaseApp.getApps().isEmpty()) {
                return;
            }

            InputStream serviceAccount = null;

            // CÁCH 1: Ưu tiên đọc file từ đường dẫn Docker Volume (đã map trong docker-compose)
            // Đường dẫn này khớp với lệnh COPY trong Dockerfile và volumes trong docker-compose
            File dockerFile = new File("/app/service-account.json");
            
            if (dockerFile.exists()) {
                System.out.println("🐳 Đang chạy trong Docker - Đọc key từ: " + dockerFile.getAbsolutePath());
                serviceAccount = new FileInputStream(dockerFile);
            } else {
                // CÁCH 2: Nếu không thấy file Docker, thử đọc từ Resources (khi chạy Local)
                System.out.println("💻 Đang chạy Local - Đọc key từ Classpath");
                ClassPathResource resource = new ClassPathResource("service-account.json");
                
                if (resource.exists()) {
                    // QUAN TRỌNG: Dùng getInputStream() thay vì getFile() để tránh lỗi trong file JAR
                    serviceAccount = resource.getInputStream();
                } else {
                    throw new RuntimeException("❌ Không tìm thấy file service-account.json ở Docker lẫn Classpath!");
                }
            }

            // Khởi tạo Firebase
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            FirebaseApp.initializeApp(options);
            System.out.println("✅✅✅ KẾT NỐI FIREBASE THÀNH CÔNG! ✅✅✅");

        } catch (Exception e) {
            System.err.println("❌❌❌ LỖI KHỞI TẠO FIREBASE: " + e.getMessage());
            e.printStackTrace();
            // Không throw exception chết chương trình để App vẫn chạy được các chức năng khác
        }
    }
}