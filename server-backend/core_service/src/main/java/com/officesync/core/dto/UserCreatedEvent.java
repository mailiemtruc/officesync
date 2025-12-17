package com.officesync.core.dto;

import java.time.LocalDate;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserCreatedEvent {
    
    private Long id;
    
    private Long companyId;

    // Map tên trường Java 'dateOfBirth' sang JSON key 'date_of_birth'
    @JsonProperty("date_of_birth") 
    private LocalDate dateOfBirth;

    private String email;
    
    private String fullName;

    // Map tên trường Java 'mobileNumber' sang JSON key 'mobile_number'
    @JsonProperty("mobile_number")
    private String mobileNumber;

    private String role;
    
    private String status;
}