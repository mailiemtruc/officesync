package com.officesync.attendance_service.repository;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.attendance_service.model.Attendance;

@Repository
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {

    // [MỚI] Tìm các bản ghi trong khoảng thời gian (từ đầu ngày đến cuối ngày)
    List<Attendance> findByUserIdAndCheckInTimeBetween(Long userId, LocalDateTime start, LocalDateTime end);

    List<Attendance> findByUserIdAndCheckInTimeBetweenOrderByCheckInTimeDesc(Long userId, LocalDateTime start, LocalDateTime end);

    // Hàm cũ (giữ nguyên để xem lịch sử)
    List<Attendance> findByUserIdOrderByCheckInTimeDesc(Long userId);

    List<Attendance> findByCheckInTimeBetweenOrderByCheckInTimeDesc(LocalDateTime start, LocalDateTime end);
}