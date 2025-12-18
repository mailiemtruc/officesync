package com.officesync.communication_service.dto;

import com.officesync.communication_service.enums.ReactionType;
import lombok.Data;

@Data
public class ReactionRequestDTO {
    private ReactionType type;
}