package com.officesync.hr_service.Repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.Department;

@Repository
public interface DepartmentRepository extends JpaRepository<Department, Long> {


    // SỬA: Đổi findByCode -> findByDepartmentCode
    Optional<Department> findByDepartmentCode(String departmentCode);
    // [MỚI] Tìm phòng ban mà nhân viên này đang làm quản lý
    Optional<Department> findByManagerId(Long managerId);
}