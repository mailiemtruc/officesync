package com.officesync.hr_service.Repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.Request;
import com.officesync.hr_service.Model.RequestStatus;

@Repository
public interface RequestRepository extends JpaRepository<Request, Long> {
List<Request> findByRequesterIdOrderByCreatedAtDesc(Long requesterId);

    // 2. Lấy danh sách đơn cần duyệt theo phòng ban (Dành cho Manager)
    List<Request> findByDepartmentIdAndStatus(Long departmentId, RequestStatus status);
    // 2. [CŨ - KHÔNG DÙNG NỮA] Lấy theo phòng ban
    List<Request> findByDepartmentIdOrderByCreatedAtDesc(Long departmentId);
// 3. [CŨ - DÙNG LẠI] Lấy tất cả đơn của công ty (cho Admin xem History)
    List<Request> findByCompanyIdOrderByCreatedAtDesc(Long companyId);
}