package com.officesync.communication_service.repository;

import com.officesync.communication_service.model.PostComment;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {
    int countByPostId(Long postId);
}