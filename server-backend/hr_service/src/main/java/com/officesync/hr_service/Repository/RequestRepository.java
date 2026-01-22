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
    
    // ... (Giữ nguyên các hàm findBy khác) ...

    List<Request> findByRequesterId(Long requesterId);
    List<Request> findByApproverId(Long approverId);
    List<Request> findByRequesterIdAndIsHiddenFalseOrderByCreatedAtDesc(Long requesterId);
    List<Request> findByDepartmentIdAndStatus(Long departmentId, RequestStatus status);
    List<Request> findByDepartmentIdOrderByCreatedAtDesc(Long departmentId);
    List<Request> findByCompanyIdOrderByCreatedAtDesc(Long companyId);

    // 1. ADMIN (Giữ nguyên Fix Fetch)
    @Query("SELECT DISTINCT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +
            "LEFT JOIN FETCH ed.manager " +      
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH d.manager " +       
            "LEFT JOIN FETCH r.approver a " +
            "WHERE r.companyId = :companyId " +
            "AND r.requester.id <> :adminId " +
            "AND (:keyword IS NULL OR (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.type) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.status) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
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

    // 2. HR: [ĐÂY LÀ PHẦN SỬA ĐỔI QUAN TRỌNG]
    @Query("SELECT DISTINCT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +
            "LEFT JOIN FETCH ed.manager " +       // [FIX] Fetch Manager để hiển thị tên
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH d.manager " +        
            "LEFT JOIN FETCH r.approver a " +
            "WHERE r.companyId = :companyId " +
            "AND r.requester.id <> :hrId " + // Không hiện đơn của chính mình (vì xem ở tab My Request rồi)
            
            // [LOGIC BẢO MẬT NỘI BỘ HR & MANAGER]
            "AND ( " +
            "   r.status <> 'PENDING' " + // CASE 1: Nếu đã Duyệt/Hủy -> Ai cũng thấy (để chấm công)
            "   OR " +
            "   ( " +
            //      CASE 2: Nếu đang PENDING -> Phải thỏa mãn:
            "       e.role <> 'MANAGER' " +       // Không phải là Manager (Manager pending chỉ Admin thấy)
            "       AND ed.isHr = false " +       // VÀ Không phải là người phòng HR (để đồng nghiệp HR ko thấy)
            "   ) " +
            "   OR " +
            //      CASE 3: Ngoại lệ -> Nếu người xem (hrId) chính là Sếp trực tiếp -> Phải thấy để duyệt
            "   (ed.manager.id = :hrId AND r.status = 'PENDING') " +
            ") " +

            "AND (:keyword IS NULL OR (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.type) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.status) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
            "AND (:day IS NULL OR DAY(r.createdAt) = :day) " +
            "AND (:month IS NULL OR MONTH(r.createdAt) = :month) " +
            "AND (:year IS NULL OR YEAR(r.createdAt) = :year) " +
            "ORDER BY r.createdAt DESC")
    List<Request> searchRequestsForHR(
            @Param("companyId") Long companyId,
            @Param("hrId") Long hrId, // ID của người đang xem danh sách
            @Param("keyword") String keyword,
            @Param("day") Integer day,
            @Param("month") Integer month,
            @Param("year") Integer year
    );

    // 3. MANAGER (Giữ nguyên)
    @Query("SELECT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +
            "LEFT JOIN FETCH ed.manager " +       
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH d.manager " +        
            "LEFT JOIN FETCH r.approver a " +
            "WHERE r.department.id = :deptId " +
            "AND r.requester.id <> :managerId " +
            "AND e.role <> 'MANAGER' " +         
            "AND e.role <> 'COMPANY_ADMIN' " +   
            "AND (:keyword IS NULL OR (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.type) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.status) LIKE LOWER(CONCAT('%', :keyword, '%')))) " +
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

    // 4. EMPLOYEE (Giữ nguyên)
    @Query("SELECT r FROM Request r " +
            "JOIN FETCH r.requester e " +
            "LEFT JOIN FETCH e.department ed " +
            "LEFT JOIN FETCH ed.manager " +      
            "LEFT JOIN FETCH r.department d " +
            "LEFT JOIN FETCH d.manager " +       
            "LEFT JOIN FETCH r.approver a " +
            "WHERE r.requester.id = :userId " +
            "AND r.isHidden = false " + 
            "AND (:keyword IS NULL OR (LOWER(r.requestCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.type) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
            "OR LOWER(r.status) LIKE LOWER(CONCAT('%', :keyword, '%')))) " + 
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