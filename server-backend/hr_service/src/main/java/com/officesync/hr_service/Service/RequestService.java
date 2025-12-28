package com.officesync.hr_service.Service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.Request;
import com.officesync.hr_service.Model.RequestAuditLog;
import com.officesync.hr_service.Model.RequestStatus;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;
import com.officesync.hr_service.Repository.RequestAuditLogRepository;
import com.officesync.hr_service.Repository.RequestRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class RequestService {

    private final RequestRepository requestRepository;
    private final EmployeeRepository employeeRepository;
    private final RequestAuditLogRepository auditLogRepository;
    private final DepartmentRepository departmentRepository; 
    private final EmployeeProducer employeeProducer;

    // --- 1. TẠO ĐƠN MỚI (AUTO-ROUTE TO HR) ---
    @Transactional
    public Request createRequest(Long userId, Request requestData) {
        // A. Lấy thông tin người tạo đơn
        Employee requester = employeeRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // B. Tìm phòng ban HR
        Department hrDept = departmentRepository.findByCompanyIdAndIsHrTrue(requester.getCompanyId())
                .orElseThrow(() -> new RuntimeException(
                    "LỖI CẤU HÌNH: Công ty chưa thiết lập Phòng Nhân Sự (is_hr=true). Vui lòng liên hệ Admin."
                ));

        // C. Setup thông tin tự động
        requestData.setRequester(requester);
        requestData.setDepartment(hrDept);
        requestData.setCompanyId(requester.getCompanyId());
        
        requestData.setStatus(RequestStatus.PENDING);
        requestData.setCreatedAt(LocalDateTime.now());
        requestData.setUpdatedAt(LocalDateTime.now());

        // D. Gọi hàm Retry để lưu Request (tránh trùng mã)
        Request savedRequest = saveRequestWithRetry(requestData);

        // E. [QUAN TRỌNG - ĐÃ SỬA] Lưu lịch sử (Audit Log) ngay khi tạo
        if (savedRequest != null) {
            saveAuditLog(savedRequest, requester, "CREATED", "Request submitted successfully");
        }

        return savedRequest;
    }

    // Hàm hỗ trợ retry khi trùng mã Request Code
    private Request saveRequestWithRetry(Request request) {
        int maxRetries = 3;
        for (int i = 0; i < maxRetries; i++) {
            try {
                request.setRequestCode(generateRandomRequestCode());
                return requestRepository.save(request);
            } catch (DataIntegrityViolationException e) {
                log.warn("Đụng độ mã Request: {}. Retry lần {}...", request.getRequestCode(), i + 1);
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Hệ thống đang bận, không thể sinh mã đơn. Vui lòng thử lại.");
                }
            }
        }
        return null;
    }

    // --- 2. DUYỆT ĐƠN ---
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

        // [TỐI ƯU] Gọi hàm chung để lưu Log
        saveAuditLog(request, approver, newStatus.name(), comment);

        return requestRepository.save(request);
    }

    // --- 3. HỦY ĐƠN (XÓA VĨNH VIỄN) ---
    @Transactional
    public void cancelRequest(Long requestId, Long userId) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));

        // 1. Kiểm tra quyền chủ sở hữu
        if (!request.getRequester().getId().equals(userId)) {
            throw new RuntimeException("Unauthorized: You do not own this request");
        }

        // 2. Chỉ xóa được khi đang chờ (PENDING)
        if (request.getStatus() != RequestStatus.PENDING) {
            throw new RuntimeException("Cannot delete processed request");
        }

        // 3. Gửi lệnh xóa file sang Storage Service qua RabbitMQ
        if (request.getEvidenceUrl() != null && !request.getEvidenceUrl().isEmpty()) {
            String[] urls = request.getEvidenceUrl().split(";");
            for (String url : urls) {
                try {
                    String fileName = url.substring(url.lastIndexOf("/") + 1);
                    log.info("--> Gửi MQ yêu cầu xóa file: {}", fileName);
                    employeeProducer.sendDeleteFileEvent(fileName);
                } catch (Exception e) {
                    log.error("Lỗi khi gửi MQ xóa file: {}", e.getMessage());
                }
            }
        }

        // 4. Xóa lịch sử Audit Log trước (để tránh lỗi Foreign Key Constraint)
        List<RequestAuditLog> logs = auditLogRepository.findByRequestIdOrderByTimestampDesc(requestId);
        if (!logs.isEmpty()) {
            auditLogRepository.deleteAll(logs);
        }

        // 5. Xóa đơn yêu cầu vĩnh viễn
        requestRepository.delete(request);
        log.info("--> Đã xóa đơn request ID: {}", requestId);
    }

    // --- 4. CÁC HÀM PHỤ TRỢ (HELPER) ---

    // [MỚI] Hàm lưu lịch sử tập trung (Tránh lặp code và tránh quên)
    private void saveAuditLog(Request request, Employee actor, String action, String comment) {
        try {
            RequestAuditLog log = new RequestAuditLog();
            log.setRequest(request);
            log.setActor(actor);
            log.setAction(action);
            log.setComment(comment);
            log.setTimestamp(LocalDateTime.now());
            auditLogRepository.save(log);
            System.out.println("--> Đã lưu Audit Log: " + action);
        } catch (Exception e) {
            // Log lỗi nhưng không chặn luồng chính
            System.err.println("Lỗi lưu Audit Log: " + e.getMessage());
        }
    }

    private String generateRandomRequestCode() {
        String datePart = LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("yyMMdd"));
        int randomNum = (int) (Math.random() * 10000);
        return "REQ" + datePart + String.format("%04d", randomNum);
    }

    public List<Request> getMyRequests(Long userId) {
        return requestRepository.findByRequesterId(userId);
    }
}