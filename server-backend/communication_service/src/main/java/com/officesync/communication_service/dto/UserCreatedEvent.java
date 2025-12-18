package com.officesync.communication_service.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import java.time.LocalDate;

@Data
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