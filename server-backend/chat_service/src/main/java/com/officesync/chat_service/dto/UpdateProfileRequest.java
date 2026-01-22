package com.officesync.chat_service.dto;

import lombok.Data;

@Data
public class UpdateProfileRequest {
    private String avatarUrl;
    private String fullName; // Để dành, phòng hờ sau này user đổi tên
}