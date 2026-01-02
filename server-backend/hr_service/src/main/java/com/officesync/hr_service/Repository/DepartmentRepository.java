package com.officesync.hr_service.Repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.Department;

@Repository
public interface DepartmentRepository extends JpaRepository<Department, Long> {

    List<Department> findByCompanyId(Long companyId);

    // SỬA: Đổi findByCode -> findByDepartmentCode
    Optional<Department> findByDepartmentCode(String departmentCode);
    // [MỚI] Tìm phòng ban mà nhân viên này đang làm quản lý
    Optional<Department> findByManagerId(Long managerId);

    @Query("SELECT d FROM Department d WHERE d.companyId = :companyId " +
           "AND (LOWER(d.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(d.departmentCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Department> searchDepartments(@Param("companyId") Long companyId, @Param("keyword") String keyword);
    

    Optional<Department> findByCompanyIdAndIsHrTrue(Long companyId);
}