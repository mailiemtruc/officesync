package com.officesync.core.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.officesync.core.model.SystemDailyStat;

public interface SystemDailyStatRepository extends JpaRepository<SystemDailyStat, Long> {
    // Lấy 7 ngày gần nhất để vẽ biểu đồ tuần
    List<SystemDailyStat> findTop7ByOrderByDateDesc();
}