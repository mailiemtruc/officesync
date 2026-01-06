package com.officesync.attendance_service.repository;
import org.springframework.data.jpa.repository.JpaRepository;

import com.officesync.attendance_service.model.AttendanceUser;

public interface AttendanceUserRepository extends JpaRepository<AttendanceUser, Long> {
}