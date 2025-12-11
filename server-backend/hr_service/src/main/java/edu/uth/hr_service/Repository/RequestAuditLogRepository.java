package edu.uth.hr_service.Repository;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import edu.uth.hr_service.Model.RequestAuditLog;



@Repository
public interface RequestAuditLogRepository extends JpaRepository<RequestAuditLog, Long> {
    // Xem lịch sử duyệt của 1 đơn
    List<RequestAuditLog> findByRequestIdOrderByTimestampDesc(Long requestId);
}