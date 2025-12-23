package com.officesync.communication_service.repository;

import com.officesync.communication_service.model.PostComment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {
    
    // Đếm số lượng comment của bài viết
    int countByPostId(Long postId);

    // ✅ THÊM DÒNG NÀY: Lấy danh sách comment, sắp xếp cũ trước mới sau (ASC)
    List<PostComment> findByPostIdOrderByCreatedAtAsc(Long postId);
}