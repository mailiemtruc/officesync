package com.officesync.notification_service.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import javax.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;

@Configuration
public class FirebaseConfig {

    // Đọc đường dẫn file từ application.properties
    @Value("${app.firebase.config-path}")
    private String firebaseConfigPath;

    @PostConstruct
    public void initialize() {
        try {
            // Kiểm tra xem đã khởi tạo chưa để tránh lỗi
            if (FirebaseApp.getApps().isEmpty()) {
                // Đọc file service-account.json từ resources
                InputStream serviceAccount = new ClassPathResource("service-account.json").getInputStream();

                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                FirebaseApp.initializeApp(options);
                System.out.println("✅ Firebase Application has been initialized");
            }
        } catch (IOException e) {
            System.err.println("❌ Lỗi khởi tạo Firebase: " + e.getMessage());
        }
    }
}