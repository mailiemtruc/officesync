package com.officesync.hr_service.Repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.Request;
import com.officesync.hr_service.Model.RequestStatus;

@Repository
public interface RequestRepository extends JpaRepository<Request, Long> {

   List<Request> findByRequesterIdAndIsHiddenFalseOrderByCreatedAtDesc(Long requesterId);
    // 2. Lấy danh sách đơn cần duyệt theo phòng ban (Dành cho Manager)
    List<Request> findByDepartmentIdAndStatus(Long departmentId, RequestStatus status);
    // 2. [CŨ - KHÔNG DÙNG NỮA] Lấy theo phòng ban
    List<Request> findByDepartmentIdOrderByCreatedAtDesc(Long departmentId);
// 3. [CŨ - DÙNG LẠI] Lấy tất cả đơn của công ty (cho Admin xem History)
    List<Request> findByCompanyIdOrderByCreatedAtDesc(Long companyId);

  // 1. Query cho ADMIN: Thấy ALL công ty, TRỪ đơn của chính mình
    @Query("SELECT r FROM Request r WHERE r.companyId = :companyId " +
           "AND r.requester.id <> :adminId " + // [QUAN TRỌNG] Không hiện đơn chính mình
           "AND (:keyword IS NULL OR (LOWER(r.requester.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.requester.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
           "AND (:day IS NULL OR DAY(r.createdAt) = :day) " +
           "AND (:month IS NULL OR MONTH(r.createdAt) = :month) " +
           "AND (:year IS NULL OR YEAR(r.createdAt) = :year) " +
           "ORDER BY r.createdAt DESC")
    List<Request> searchRequestsForAdmin(
        @Param("companyId") Long companyId, 
        @Param("adminId") Long adminId,
        @Param("keyword") String keyword,
        @Param("day") Integer day,
        @Param("month") Integer month,
        @Param("year") Integer year
    );

    // 2. Query cho HR: Thấy ALL công ty, TRỪ đơn của Manager, TRỪ đơn chính mình
    @Query("SELECT r FROM Request r WHERE r.companyId = :companyId " +
           "AND r.requester.id <> :hrId " + // Không hiện đơn chính mình
           "AND r.requester.role <> 'MANAGER' " + // [QUAN TRỌNG] HR không thấy đơn của Manager (để Admin duyệt)
           "AND (:keyword IS NULL OR (LOWER(r.requester.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.requester.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
           "AND (:day IS NULL OR DAY(r.createdAt) = :day) " +
           "AND (:month IS NULL OR MONTH(r.createdAt) = :month) " +
           "AND (:year IS NULL OR YEAR(r.createdAt) = :year) " +
           "ORDER BY r.createdAt DESC")
    List<Request> searchRequestsForHR(
        @Param("companyId") Long companyId, 
        @Param("hrId") Long hrId,
        @Param("keyword") String keyword,
        @Param("day") Integer day,
        @Param("month") Integer month,
        @Param("year") Integer year
    );

    // 3. Query cho MANAGER: Thấy đơn PHÒNG BAN MÌNH, TRỪ đơn chính mình
    @Query("SELECT r FROM Request r WHERE r.department.id = :deptId " +
           "AND r.requester.id <> :managerId " + // [QUAN TRỌNG] Không hiện đơn chính mình
           "AND (:keyword IS NULL OR (LOWER(r.requester.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.requester.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
           "AND (:day IS NULL OR DAY(r.createdAt) = :day) " +
           "AND (:month IS NULL OR MONTH(r.createdAt) = :month) " +
           "AND (:year IS NULL OR YEAR(r.createdAt) = :year) " +
           "ORDER BY r.createdAt DESC")
    List<Request> searchRequestsForManager(
        @Param("deptId") Long deptId, 
        @Param("managerId") Long managerId,
        @Param("keyword") String keyword,
        @Param("day") Integer day,
        @Param("month") Integer month,
        @Param("year") Integer year
    );

    // 3. Query cho NHÂN VIÊN (Sửa)
    @Query("SELECT r FROM Request r WHERE r.requester.id = :userId " +
           "AND (:keyword IS NULL OR (LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(r.type) LIKE LOWER(CONCAT('%', :keyword, '%')))) " + // [MỚI THÊM DÒNG NÀY]
           "AND (:day IS NULL OR DAY(r.createdAt) = :day) " +     // [MỚI THÊM]
           "AND (:month IS NULL OR MONTH(r.createdAt) = :month) " +
           "AND (:year IS NULL OR YEAR(r.createdAt) = :year) " +
           "ORDER BY r.createdAt DESC")
    List<Request> searchRequestsForEmployee(
        @Param("userId") Long userId,
        @Param("keyword") String keyword,
        @Param("day") Integer day,     // [MỚI]
        @Param("month") Integer month,
        @Param("year") Integer year
    );
}