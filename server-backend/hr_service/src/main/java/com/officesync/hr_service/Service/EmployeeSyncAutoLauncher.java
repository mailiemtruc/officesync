package com.officesync.hr_service.Service;

import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Producer.EmployeeProducer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
@Slf4j
public class EmployeeSyncAutoLauncher {

    private final EmployeeProducer employeeProducer;

    // Sử dụng TransactionalEventListener để đảm bảo sau khi DB lưu xong mới bắn MQ
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handleSyncAfterDbCommit(Employee emp) {
        try {
            String deptName = (emp.getDepartment() != null) ? emp.getDepartment().getName() : "N/A";
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                emp.getId(), emp.getEmail(), emp.getFullName(), emp.getPhone(),
                emp.getDateOfBirth(), emp.getCompanyId(), emp.getRole().name(),
                emp.getStatus().name(), null, deptName,
                emp.getDepartment() != null ? emp.getDepartment().getId() : null
            );
            
            // Luôn ưu tiên dùng hàm Direct để tránh lỗi Conversion bên Task
            employeeProducer.sendEmployeeCreatedEventDirect(event);
            log.info("🚀 [Auto-Sync] Đã đẩy dữ liệu nhân viên {} (ID: {}) sang Task Service.", emp.getFullName(), emp.getId());
        } catch (Exception e) {
            log.error("❌ [Auto-Sync] Lỗi bắn tin nhắn tự động: {}", e.getMessage());
        }
    }
}