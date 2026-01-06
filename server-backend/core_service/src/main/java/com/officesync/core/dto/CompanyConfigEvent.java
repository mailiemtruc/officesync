package com.officesync.core.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class CompanyConfigEvent {
    private Long companyId;
    private String officeName; // Thường lấy tên công ty làm tên văn phòng chính
    private Double latitude;
    private Double longitude;
    private Double allowedRadius;
    private String wifiBssid;
    private String wifiSsid;
}