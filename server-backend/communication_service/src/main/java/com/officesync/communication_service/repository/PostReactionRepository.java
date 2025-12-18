package com.officesync.communication_service.repository;

import com.officesync.communication_service.model.PostReaction;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface PostReactionRepository extends JpaRepository<PostReaction, Long> {
    Optional<PostReaction> findByPostIdAndUserId(Long postId, Long userId);
    int countByPostId(Long postId);
}