package com.officesync.attendance_service.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.attendance_service.model.OfficeConfig;

@Repository
public interface OfficeConfigRepository extends JpaRepository<OfficeConfig, Long> {

    // Tìm cấu hình theo công ty
    List<OfficeConfig> findByCompanyId(Long companyId);
}
