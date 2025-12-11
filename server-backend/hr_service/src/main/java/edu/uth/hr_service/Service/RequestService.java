package edu.uth.hr_service.Service;

import java.time.LocalDateTime;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import edu.uth.hr_service.Model.Employee;
import edu.uth.hr_service.Model.Request;
import edu.uth.hr_service.Model.RequestAuditLog;
import edu.uth.hr_service.Model.RequestStatus;
import edu.uth.hr_service.Repository.EmployeeRepository;
import edu.uth.hr_service.Repository.RequestAuditLogRepository;
import edu.uth.hr_service.Repository.RequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class RequestService {

    private final RequestRepository requestRepository;
    private final EmployeeRepository employeeRepository;
    private final RequestAuditLogRepository auditLogRepository;

    // --- TẠO ĐƠN MỚI (CÓ RETRY) ---
    public Request createRequest(Long userId, Request requestData) {
        // 1. Chuẩn bị dữ liệu
        Employee requester = employeeRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        requestData.setRequester(requester);
        requestData.setDepartment(requester.getDepartment());
        requestData.setCompanyId(requester.getCompanyId());
        requestData.setStatus(RequestStatus.PENDING);

        // 2. Gọi hàm lưu an toàn
        return saveRequestWithRetry(requestData);
    }

    private Request saveRequestWithRetry(Request request) {
        int maxRetries = 3;
        for (int i = 0; i < maxRetries; i++) {
            try {
                request.setRequestCode(generateRandomRequestCode());
                return requestRepository.save(request);
            } catch (DataIntegrityViolationException e) {
                log.warn("Đụng độ mã Request: {}. Retry lần {}...", request.getRequestCode(), i + 1);
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Không thể tạo đơn lúc này. Vui lòng thử lại.");
                }
            }
        }
        return null;
    }

    // --- DUYỆT ĐƠN (Giữ nguyên, không cần retry vì không sinh mã mới) ---
    @Transactional
    public Request approveRequest(Long requestId, Long approverId, RequestStatus newStatus, String comment) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));
        
        Employee approver = employeeRepository.findById(approverId)
                .orElseThrow(() -> new RuntimeException("Approver not found"));

        if (request.getStatus() != RequestStatus.PENDING) {
            throw new RuntimeException("Request is not in PENDING state");
        }

        request.setStatus(newStatus);
        request.setApprover(approver);
        
        if (newStatus == RequestStatus.REJECTED) {
            request.setRejectReason(comment);
        }

        // Lưu Audit Log
        RequestAuditLog log = new RequestAuditLog();
        log.setRequest(request);
        log.setActor(approver);
        log.setAction(newStatus.name());
        log.setComment(comment);
        log.setTimestamp(LocalDateTime.now());
        auditLogRepository.save(log);

        return requestRepository.save(request);
    }

    private String generateRandomRequestCode() {
        String datePart = LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("yyMMdd"));
        int randomNum = (int) (Math.random() * 10000);
        return "REQ" + datePart + String.format("%04d", randomNum);
    }
}