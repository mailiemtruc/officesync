package edu.uth.hr_service.Repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import edu.uth.hr_service.Model.Request;
import edu.uth.hr_service.Model.RequestStatus;

@Repository
public interface RequestRepository extends JpaRepository<Request, Long> {
    // 1. Lấy lịch sử đơn từ của chính mình
    List<Request> findByRequesterId(Long requesterId);

    // 2. Lấy danh sách đơn cần duyệt theo phòng ban (Dành cho Manager)
    List<Request> findByDepartmentIdAndStatus(Long departmentId, RequestStatus status);

    // Check trùng mã request
    boolean existsByRequestCode(String requestCode);
}