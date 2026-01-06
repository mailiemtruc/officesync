package com.officesync.attendance_service.repository;

import com.officesync.attendance_service.model.Attendance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface AttendanceRepository extends JpaRepository<Attendance, Long> {

    // Xem lịch sử chấm công của nhân viên
    List<Attendance> findByUserIdOrderByCheckInTimeDesc(Long userId);
}
