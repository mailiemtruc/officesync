package com.officesync.storage.controller;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.officesync.storage.service.FileStorageService;

@RestController
@RequestMapping("/api/files")
@CrossOrigin(origins = "*")
public class FileUploadController {

    @Autowired
    private FileStorageService fileStorageService;

    @PostMapping("/upload")
    public ResponseEntity<?> uploadFile(@RequestParam("file") MultipartFile file) {
        try {
            // Gọi Service để xử lý lưu file
            String fileUrl = fileStorageService.storeFile(file);
            
            // Trả về kết quả
            return ResponseEntity.ok(Map.of("url", fileUrl));
            
        } catch (RuntimeException ex) {
            return ResponseEntity.internalServerError().body(ex.getMessage());
        }
    }
}