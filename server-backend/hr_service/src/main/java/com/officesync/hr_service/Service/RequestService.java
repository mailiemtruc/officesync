package com.officesync.hr_service.Service;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional; 

import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
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
   private final SimpMessagingTemplate messagingTemplate;
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
       if (savedRequest != null) {
            saveAuditLog(savedRequest, requester, "CREATED", "Request submitted successfully");
            // [FIX REALTIME 1] Bắn tin "NEW_REQUEST" cho Manager
            // Manager đang lắng nghe tại: /topic/company/{companyId}/requests
            try {
                String destination = "/topic/company/" + requester.getCompanyId() + "/requests";
                log.info("--> [WS] Bắn tin 'NEW_REQUEST' tới: {}", destination);
                // Gửi chuỗi "NEW_REQUEST" để App Manager biết mà reload list
                messagingTemplate.convertAndSend(destination, "NEW_REQUEST"); 
            } catch (Exception e) {
                log.error("Lỗi gửi WS Create: {}", e.getMessage());
            }
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



   // --- 2. DUYỆT ĐƠN (ĐÃ SỬA LOGIC PHÂN QUYỀN CHẶT CHẼ) ---
    @Transactional
    public Request approveRequest(Long requestId, Long approverId, RequestStatus newStatus, String comment) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));
        Employee approver = employeeRepository.findById(approverId)
                .orElseThrow(() -> new RuntimeException("Approver not found"));

        // 1. Không được tự duyệt đơn của chính mình
        if (request.getRequester().getId().equals(approverId)) {
            throw new RuntimeException("Bạn không thể tự duyệt/từ chối đơn của chính mình.");
        }

        EmployeeRole approverRole = approver.getRole();
        EmployeeRole requesterRole = request.getRequester().getRole();
        boolean isHrApprover = isHrEmployee(approver);
        boolean isAdmin = approverRole == EmployeeRole.COMPANY_ADMIN;

        // 2. Logic phân quyền duyệt đơn [MỚI]

        // RULE A: Nếu người tạo đơn là MANAGER (Bất kể manager phòng nào) -> Chỉ ADMIN mới được duyệt
        if (requesterRole == EmployeeRole.MANAGER) {
            if (!isAdmin) {
                throw new RuntimeException("Chỉ Giám đốc (Admin) mới có quyền duyệt đơn của Quản lý (Manager).");
            }
        }
        // RULE B: Nếu người tạo đơn là nhân viên phòng HR -> Chỉ HR Manager hoặc Admin được duyệt
        else if (isHrEmployee(request.getRequester())) {
            // Kiểm tra: Người duyệt phải là Admin HOẶC (Là Manager VÀ thuộc phòng HR)
            boolean isHrManager = (approverRole == EmployeeRole.MANAGER && isHrApprover);
            if (!isAdmin && !isHrManager) {
                throw new RuntimeException("Đơn của nhân viên HR chỉ được duyệt bởi Quản lý phòng HR hoặc Giám đốc.");
            }
        }
        // RULE C: Nhân viên bình thường các phòng ban khác
        else {
            // Cho phép: Admin, HR Staff/Manager, Manager của phòng ban đó
            boolean isSameDeptManager = (approverRole == EmployeeRole.MANAGER 
                                        && request.getDepartment().getId().equals(approver.getDepartment().getId()));
            
            if (!isAdmin && !isHrApprover && !isSameDeptManager) {
                throw new RuntimeException("Bạn không có quyền duyệt đơn này.");
            }
        }

        // 3. Tiến hành cập nhật trạng thái
        if (request.getStatus() != RequestStatus.PENDING) {
            throw new RuntimeException("Đơn này đã được xử lý trước đó.");
        }

        request.setStatus(newStatus);
        request.setApprover(approver);

        if (newStatus == RequestStatus.REJECTED) {
            request.setRejectReason(comment);
        }
        
        saveAuditLog(request, approver, newStatus.name(), comment);
        Request savedRequest = requestRepository.save(request);

        // [SOCKET] Gửi thông báo realtime
        try {
            // Gửi vào trang chi tiết
            String detailDest = "/topic/request/" + savedRequest.getId();
            messagingTemplate.convertAndSend(detailDest, savedRequest);

            // Gửi cho User
            String userDest = "/topic/user/" + savedRequest.getRequester().getId() + "/requests";
            messagingTemplate.convertAndSend(userDest, savedRequest);

            // Gửi update list cho Manager
            String companyDest = "/topic/company/" + savedRequest.getCompanyId() + "/requests";
            messagingTemplate.convertAndSend(companyDest, savedRequest);
        } catch (Exception e) {
            log.error("Lỗi gửi WebSocket: " + e.getMessage());
        }
        return savedRequest;
    }

// --- 3. LẤY DANH SÁCH DUYỆT (ĐÃ SỬA LỖI HIỂN THỊ) ---
    public List<Request> getRequestsForManager(Long requesterId, String keyword, Integer day, Integer month, Integer year) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        String searchKey = (keyword != null && !keyword.trim().isEmpty()) ? keyword.trim() : null;

        boolean isAdmin = requester.getRole() == EmployeeRole.COMPANY_ADMIN;
        boolean isManager = requester.getRole() == EmployeeRole.MANAGER;
        boolean isHrStaff = isHrEmployee(requester);

        // CASE 1: ADMIN -> Thấy tất cả (trừ của mình)
        if (isAdmin) {
            return requestRepository.searchRequestsForAdmin(
                requester.getCompanyId(), requesterId, searchKey, day, month, year
            );
        }

        // CASE 2: HR (Nhân viên hoặc Quản lý HR) -> Thấy tất cả STAFF (Không thấy đơn Manager, Không thấy đơn của chính mình)
        if (isHrStaff) {
            return requestRepository.searchRequestsForHR(
                requester.getCompanyId(), requesterId, searchKey, day, month, year
            );
        }

        // CASE 3: MANAGER THƯỜNG (Không phải HR) -> Chỉ thấy đơn phòng mình (Không thấy đơn của chính mình)
        if (isManager) {
            Department dept = requester.getDepartment();
            if (dept != null) {
                return requestRepository.searchRequestsForManager(
                    dept.getId(), requesterId, searchKey, day, month, year
                );
            }
        }

        // Nếu là Staff thường (không phải HR) -> Không thấy gì trong trang quản lý
        return Collections.emptyList();
    }

    private boolean isHrEmployee(Employee emp) {
        if (emp.getDepartment() == null) return false;

        return Boolean.TRUE.equals(emp.getDepartment().getIsHr());
    }


  @Transactional
    public void cancelRequest(Long requestId, Long userId) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));

        // 1. Check quyền chính chủ
        if (!request.getRequester().getId().equals(userId)) {
            throw new RuntimeException("Unauthorized: You do not own this request");
        }

        // --- TRƯỜNG HỢP 1: Đơn đang chờ (PENDING) -> XÓA VĨNH VIỄN KHỎI DB ---
        // (Logic này giống hệt code gốc của bạn)
        if (request.getStatus() == RequestStatus.PENDING) {
            
            Long reqId = request.getId();
            Long companyId = request.getCompanyId();

            // A. Xóa file đính kèm trên server (nếu có)
            if (request.getEvidenceUrl() != null && !request.getEvidenceUrl().isEmpty()) {
                String[] urls = request.getEvidenceUrl().split(";");
                for (String url : urls) {
                    try {
                        String fileName = url.substring(url.lastIndexOf("/") + 1);
                        employeeProducer.sendDeleteFileEvent(fileName);
                    } catch (Exception e) {
                        log.error("Lỗi MQ xóa file: {}", e.getMessage());
                    }
                }
            }

            // B. Xóa Audit Log (Lịch sử thao tác) liên quan đến đơn này
            List<RequestAuditLog> logs = auditLogRepository.findByRequestIdOrderByTimestampDesc(requestId);
            if (!logs.isEmpty()) {
                auditLogRepository.deleteAll(logs);
            }

            // C. Xóa đơn khỏi Database
            requestRepository.delete(request);
            log.info("--> Đã xóa vĩnh viễn đơn request ID: {}", reqId);

            // D. Bắn Socket báo Frontend xóa dòng này trên giao diện
            try {
                // Tạo object rỗng chỉ chứa ID để Frontend biết mà xóa
                Request deletedPayload = new Request();
                deletedPayload.setId(reqId);
                deletedPayload.setCompanyId(companyId);
                // Lưu ý: Không setStatus(CANCELLED) vì bạn không dùng enum này.
                // Frontend chỉ cần check ID để removeWhere.

                // 1. Báo trang chi tiết (nếu đang mở)
                messagingTemplate.convertAndSend("/topic/request/" + reqId, deletedPayload);

                // 2. Báo danh sách Manager (để xóa dòng đó khỏi màn hình Manager)
                messagingTemplate.convertAndSend("/topic/company/" + companyId + "/requests", deletedPayload);

            } catch (Exception e) {
                log.error("Lỗi gửi WebSocket Delete: " + e.getMessage());
            }
        } 
        
        // --- TRƯỜNG HỢP 2: Đơn đã xử lý (APPROVED / REJECTED) -> CHỈ ẨN ĐI (Soft Delete) ---
        // (Logic mới thêm để tăng trải nghiệm người dùng)
        else {
            // Không xóa data để giữ lịch sử chấm công, chỉ bật cờ ẩn
            request.setIsHidden(true);
            requestRepository.save(request);
            log.info("--> Đã ẩn đơn (Soft Delete) khỏi danh sách cá nhân ID: {}", requestId);
        }
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

// 2. Sửa hàm getMyRequests (Dùng cho Nhân viên xem đơn của mình)
public List<Request> getMyRequests(Long userId, String keyword,Integer day, Integer month, Integer year) {
    String searchKey = (keyword != null && !keyword.trim().isEmpty()) ? keyword.trim() : null;
    
    return requestRepository.searchRequestsForEmployee(
        userId, searchKey,day, month, year
    );
}
}