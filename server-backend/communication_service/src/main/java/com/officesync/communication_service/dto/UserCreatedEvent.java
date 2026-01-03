package com.officesync.communication_service.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor; // Thêm
import lombok.Data;
import lombok.NoArgsConstructor;  // Thêm

import java.time.LocalDate;

@Data
@AllArgsConstructor // ✅ Quan trọng cho Jackson
@NoArgsConstructor  // ✅ Quan trọng cho Jackson
public class UserCreatedEvent {
    private Long id;
    private Long companyId;
    private String email;
    private String fullName;
    private String role;
    private String status;

    @JsonProperty("mobile_number")
    private String mobileNumber;

    @JsonProperty("date_of_birth")
    private LocalDate dateOfBirth;
}