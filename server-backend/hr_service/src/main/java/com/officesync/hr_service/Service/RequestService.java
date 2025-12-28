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
    private final EmployeeProducer employeeProducer; // [QUAN TRỌNG] Inject để gửi MQ
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
        // [SỬA] Không set Request Code ở đây nữa, vì hàm retry bên dưới sẽ làm việc đó
        requestData.setCreatedAt(LocalDateTime.now());
        requestData.setUpdatedAt(LocalDateTime.now());

        // D. [SỬA QUAN TRỌNG] Gọi hàm Retry thay vì save trực tiếp
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

    // [MỚI] Hàm lấy danh sách đơn từ của chính user đó
    public List<Request> getMyRequests(Long userId) {
        // Kiểm tra user có tồn tại không (nếu cần thiết)
        // Employee requester = employeeRepository.findById(userId) ...
        
        // Gọi Repository lấy list
        return requestRepository.findByRequesterId(userId);
    }

    // [SỬA LẠI] Hàm Hủy đơn -> Chuyển thành XÓA VĨNH VIỄN & XÓA FILE
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

        // 3. [LOGIC MỚI] Gửi lệnh xóa file sang Storage Service qua RabbitMQ
        if (request.getEvidenceUrl() != null && !request.getEvidenceUrl().isEmpty()) {
            // Chuỗi URL dạng: "http://.../img1.jpg;http://.../img2.mp4"
            String[] urls = request.getEvidenceUrl().split(";");
            
            for (String url : urls) {
                try {
                    // Cắt lấy tên file cuối cùng. VD: http://localhost:8090/img/abc.jpg -> abc.jpg
                    String fileName = url.substring(url.lastIndexOf("/") + 1);
                    
                    log.info("--> Gửi MQ yêu cầu xóa file: {}", fileName);
                    employeeProducer.sendDeleteFileEvent(fileName);
                } catch (Exception e) {
                    log.error("Lỗi khi gửi MQ xóa file: {}", e.getMessage());
                    // Không ném lỗi để tiếp tục xóa DB
                }
            }
        }

        // 4. Xóa lịch sử Audit Log trước (để tránh lỗi Foreign Key Constraint)
        // Tìm các log liên quan đến request này và xóa
        List<RequestAuditLog> logs = auditLogRepository.findByRequestIdOrderByTimestampDesc(requestId);
        if (!logs.isEmpty()) {
            auditLogRepository.deleteAll(logs);
        }

        // 5. Xóa đơn yêu cầu vĩnh viễn
        requestRepository.delete(request);
        log.info("--> Đã xóa đơn request ID: {}", requestId);
    }
}