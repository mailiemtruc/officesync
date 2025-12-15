package com.officesync.core.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.core.model.PasswordHistory;

@Repository
public interface PasswordHistoryRepository extends JpaRepository<PasswordHistory, Long> {
    // Lấy danh sách lịch sử mật khẩu của User, sắp xếp giảm dần theo thời gian
    List<PasswordHistory> findByUserIdOrderByCreatedAtDesc(Long userId);
}