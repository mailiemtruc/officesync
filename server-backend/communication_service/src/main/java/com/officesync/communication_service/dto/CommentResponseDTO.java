package com.officesync.communication_service.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Builder
public class CommentResponseDTO {
    private Long id;
    private String content;
    private Long parentId; 
    
    // Thông tin người bình luận (để App hiển thị)
    private Long userId;
    private String authorName;
    private String authorAvatar;
    
    private LocalDateTime createdAt;
}