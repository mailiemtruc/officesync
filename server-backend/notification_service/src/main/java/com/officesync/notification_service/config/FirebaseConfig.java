package com.officesync.notification_service.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;

@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void initialize() {
        System.out.println("=============================================================");
        System.out.println("🔥🔥🔥 BẮT ĐẦU KHỞI TẠO FIREBASE... 🔥🔥🔥");
        System.out.println("=============================================================");

        try {
            if (FirebaseApp.getApps().isEmpty()) {
                // 1. Cố gắng đọc file
                ClassPathResource resource = new ClassPathResource("service-account.json");
                
                // Kiểm tra xem file có tồn tại thật không
                if (!resource.exists()) {
                    throw new RuntimeException("❌ TÌM KHÔNG THẤY FILE 'service-account.json' TRONG RESOURCES!");
                }
                
                InputStream serviceAccount = resource.getInputStream();

                // 2. Nạp vào Firebase
                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                        .build();

                FirebaseApp.initializeApp(options);
                System.out.println("✅✅✅ KẾT NỐI FIREBASE THÀNH CÔNG RỰC RỠ! ✅✅✅");
            }
        } catch (Exception e) {
            System.err.println("❌❌❌ LỖI NGHIÊM TRỌNG KHI KHỞI TẠO FIREBASE ❌❌❌");
            e.printStackTrace();
            // Lệnh này sẽ làm sập Server ngay lập tức để bạn biết có lỗi
            throw new RuntimeException("Không thể khởi động Server vì lỗi Firebase: " + e.getMessage());
        }
    }
}