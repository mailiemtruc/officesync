package com.officesync.hr_service.DTO;

import java.time.LocalDate;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class UserCreatedEvent {
    private Long id;
    private Long companyId;
    @JsonProperty("date_of_birth") 
    private LocalDate dateOfBirth;
    private String email;
    private String fullName;
    @JsonProperty("mobile_number")
    private String mobileNumber;
    private String role;
    private String status;
}