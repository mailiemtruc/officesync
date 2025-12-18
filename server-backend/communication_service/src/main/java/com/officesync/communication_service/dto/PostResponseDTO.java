package com.officesync.communication_service.dto;

import com.officesync.communication_service.enums.ReactionType;
import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Builder
public class PostResponseDTO {
    private Long id;
    private String content;
    private String imageUrl;
    
    private Long authorId;
    private String authorName;
    private String authorAvatar;
    
    private LocalDateTime createdAt;
    
    private int reactionCount;
    private int commentCount;
    private ReactionType myReaction;
}