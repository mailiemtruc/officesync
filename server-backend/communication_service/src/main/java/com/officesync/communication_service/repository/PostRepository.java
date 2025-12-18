package com.officesync.communication_service.repository;

import com.officesync.communication_service.model.Post;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface PostRepository extends JpaRepository<Post, Long> {
    List<Post> findByCompanyIdOrderByCreatedAtDesc(Long companyId);
}