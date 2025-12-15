package com.officesync.storage.config;

import java.nio.file.Paths;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Lấy đường dẫn tuyệt đối tới thư mục 'img'
        String uploadPath = Paths.get("img").toAbsolutePath().toUri().toString();

        // Mở quyền truy cập: Ai gọi vào đường dẫn /img/** sẽ trỏ vào thư mục thật
        registry.addResourceHandler("/img/**")
                .addResourceLocations(uploadPath);
    }
}
