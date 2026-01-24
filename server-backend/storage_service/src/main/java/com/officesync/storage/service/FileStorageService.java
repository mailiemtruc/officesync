package com.officesync.storage.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Objects;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;
// Bỏ import ServletUriComponentsBuilder vì không dùng nữa

@Service
public class FileStorageService {

    private final Path fileStorageLocation;

    public FileStorageService() {
        this.fileStorageLocation = Paths.get("img").toAbsolutePath().normalize();
        try {
            Files.createDirectories(this.fileStorageLocation);
        } catch (Exception ex) {
            throw new RuntimeException("Could not create upload directory", ex);
        }
    }

    public String storeFile(MultipartFile file) {
        try {
            // 1. Làm sạch tên file
            String originalFileName = StringUtils.cleanPath(Objects.requireNonNull(file.getOriginalFilename()));
            
            // 2. Tạo tên file duy nhất
            String uniqueFileName = UUID.randomUUID().toString() + "_" + originalFileName;

            // 3. Lưu file vào ổ cứng
            Path targetLocation = this.fileStorageLocation.resolve(uniqueFileName);
            Files.copy(file.getInputStream(), targetLocation, StandardCopyOption.REPLACE_EXISTING);

            // 🔴 4. [SỬA ĐOẠN NÀY] Trả về link cứng trỏ vào Gateway (Port 8000)
            // Lưu ý: Đây là hardcode, chỉ dùng tốt cho dev/test trên máy tính
            return "http://localhost:8000/img/" + uniqueFileName;

        } catch (IOException ex) {
            throw new RuntimeException("Could not upload file: " + ex.getMessage());
        }
    }

    public void deleteFile(String fileName) {
        try {
            Path filePath = this.fileStorageLocation.resolve(fileName).normalize();
            Files.deleteIfExists(filePath);
        } catch (IOException ex) {
            throw new RuntimeException("File not found " + fileName, ex);
        }
    }
}