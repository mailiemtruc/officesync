package com.officesync.communication_service.model;

import com.officesync.communication_service.enums.ReactionType;
import jakarta.persistence.*;
import lombok.Data;

@Entity
@Table(name = "post_reactions")
@Data
public class PostReaction {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "reaction_type", nullable = false)
    private ReactionType reactionType;
}