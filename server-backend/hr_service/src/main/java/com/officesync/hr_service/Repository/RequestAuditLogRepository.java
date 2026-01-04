package com.officesync.hr_service.Repository;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.RequestAuditLog;



@Repository
public interface RequestAuditLogRepository extends JpaRepository<RequestAuditLog, Long> {
    // Xem lịch sử duyệt của 1 đơn
    List<RequestAuditLog> findByRequestIdOrderByTimestampDesc(Long requestId);
    // [MỚI] Tìm log theo Request ID (để xóa khi xóa đơn)
    // Lưu ý: Tên hàm phải chính xác như thế này vì trong Service bạn gọi .findByRequestId(...)
    List<RequestAuditLog> findByRequestId(Long requestId);

    // [MỚI] Tìm log theo người thực hiện (để xóa khi xóa nhân viên)
    List<RequestAuditLog> findByActorId(Long actorId);
}