package com.officesync.communication_service.dto;

import lombok.Data;

@Data
public class CommentRequestDTO {
    private String content;
    private Long parentId;
}