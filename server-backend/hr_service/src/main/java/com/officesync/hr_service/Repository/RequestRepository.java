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
  // [MỚI] Tìm tất cả đơn của người tạo (để xóa khi nhân viên nghỉ việc)
    List<Request> findByRequesterId(Long requesterId);
    // [MỚI] Tìm tất cả đơn mà người này là người duyệt (để gỡ tên)
    List<Request> findByApproverId(Long approverId);
    
   List<Request> findByRequesterIdAndIsHiddenFalseOrderByCreatedAtDesc(Long requesterId);
    // 2. Lấy danh sách đơn cần duyệt theo phòng ban (Dành cho Manager)
    List<Request> findByDepartmentIdAndStatus(Long departmentId, RequestStatus status);
    // 2. [CŨ - KHÔNG DÙNG NỮA] Lấy theo phòng ban
    List<Request> findByDepartmentIdOrderByCreatedAtDesc(Long departmentId);
// 3. [CŨ - DÙNG LẠI] Lấy tất cả đơn của công ty (cho Admin xem History)
    List<Request> findByCompanyIdOrderByCreatedAtDesc(Long companyId);

  // 1. Query cho ADMIN
    @Query("SELECT r FROM Request r " +
            "JOIN FETCH r.requester e " +           // Lấy nhân viên tạo đơn
            "LEFT JOIN FETCH e.department ed " +    // [FIX LỖI 1] Lấy phòng ban của nhân viên để hàm getDepartmentName() không query lại
            "LEFT JOIN FETCH r.department d " +     // Lấy phòng ban của đơn
            "LEFT JOIN FETCH r.approver a " +       // [FIX LỖI 2] Lấy thông tin người duyệt (để hiện tên sếp duyệt)
            "WHERE r.companyId = :companyId " +
            "AND r.requester.id <> :adminId " +
            "AND (:keyword IS NULL OR (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
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

    // 2. Query cho HR
    @Query("SELECT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +    // [FIX LỖI 1]
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH r.approver a " +       // [FIX LỖI 2]
            "WHERE r.companyId = :companyId " +
            "AND r.requester.id <> :hrId " +
            "AND e.role <> 'MANAGER' " +
            "AND (:keyword IS NULL OR (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
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

    // 3. Query cho MANAGER
    @Query("SELECT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +    // [FIX LỖI 1]
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH r.approver a " +       // [FIX LỖI 2]
            "WHERE r.department.id = :deptId " +
            "AND r.requester.id <> :managerId " +
            "AND (:keyword IS NULL OR (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
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

    // 4. Query cho NHÂN VIÊN
    @Query("SELECT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +    // [FIX LỖI 1]
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH r.approver a " +       // [FIX LỖI 2]
            "WHERE r.requester.id = :userId " +
            "AND (:keyword IS NULL OR (LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.type) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
            "AND (:day IS NULL OR DAY(r.createdAt) = :day) " +
            "AND (:month IS NULL OR MONTH(r.createdAt) = :month) " +
            "AND (:year IS NULL OR YEAR(r.createdAt) = :year) " +
            "ORDER BY r.createdAt DESC")
    List<Request> searchRequestsForEmployee(
            @Param("userId") Long userId,
            @Param("keyword") String keyword,
            @Param("day") Integer day,
            @Param("month") Integer month,
            @Param("year") Integer year
    );
}