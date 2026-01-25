package com.officesync.hr_service.DTO;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class UserStatusChangedEvent {
    private Long userId;   // ID của user (Core ID)
    private String status; // "ACTIVE" hoặc "LOCKED"
}