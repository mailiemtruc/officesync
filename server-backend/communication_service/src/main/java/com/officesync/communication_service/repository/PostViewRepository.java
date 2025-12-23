package com.officesync.communication_service.repository;

import com.officesync.communication_service.model.PostView;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PostViewRepository extends JpaRepository<PostView, Long> {
    // Kiểm tra xem user này đã xem bài này chưa
    boolean existsByPostIdAndUserId(Long postId, Long userId);
}