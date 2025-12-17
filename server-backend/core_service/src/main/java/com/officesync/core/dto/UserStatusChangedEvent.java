package com.officesync.core.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserStatusChangedEvent {
    private Long userId;
    private String status; // "ACTIVE" hoặc "LOCKED"
}