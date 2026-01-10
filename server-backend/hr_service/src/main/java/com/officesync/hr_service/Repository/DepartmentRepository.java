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

    // [MỚI - CHUẨN DOANH NGHIỆP]
    // Sử dụng LEFT JOIN FETCH để load luôn thông tin Manager trong cùng 1 câu lệnh SQL
    @Query("SELECT d FROM Department d LEFT JOIN FETCH d.manager WHERE d.companyId = :companyId")
    List<Department> findByCompanyId(@Param("companyId") Long companyId);

    // SỬA: Tìm kiếm cũng phải fetch manager luôn để hiển thị lên Card
    @Query("SELECT d FROM Department d LEFT JOIN FETCH d.manager WHERE d.companyId = :companyId " +
           "AND (LOWER(d.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(d.departmentCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Department> searchDepartments(@Param("companyId") Long companyId, @Param("keyword") String keyword);


    // Các hàm phụ trợ khác giữ nguyên hoặc thêm FETCH nếu cần
    Optional<Department> findByDepartmentCode(String departmentCode);
    Optional<Department> findByManagerId(Long managerId);
    
    // Tìm phòng HR
    @Query("SELECT d FROM Department d LEFT JOIN FETCH d.manager WHERE d.companyId = :companyId AND d.isHr = true")
    Optional<Department> findByCompanyIdAndIsHrTrue(@Param("companyId") Long companyId);
}