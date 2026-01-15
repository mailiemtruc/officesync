package com.officesync.chat_service.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties; // Import này
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true) // [QUAN TRỌNG] Thêm dòng này
public class UserCreatedEvent {
    private Long id;
    private Long companyId;
    private String email;
    private String fullName;
    private String role;
    private String status;
    
    // Nếu trong JSON có mấy trường date_of_birth mà bạn không cần dùng bên Chat
    // thì kệ nó, @JsonIgnoreProperties sẽ bỏ qua giúp bạn không bị lỗi.
}