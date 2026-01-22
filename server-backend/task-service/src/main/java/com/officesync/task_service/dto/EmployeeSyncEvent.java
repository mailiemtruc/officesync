
package com.officesync.task_service.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;

@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class EmployeeSyncEvent {
    private Long id; 
    private String email;
    private String fullName;
    private String phone;
    @JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd")
    private LocalDate dateOfBirth;
    private Long companyId;     // Vị trí 6
    private String role;        // Vị trí 7
    private String status;      // Vị trí 8
    private String password;    // Vị trí 9
    private String departmentName; // Vị trí 10
    private Long departmentId;     // Vị trí 11
}