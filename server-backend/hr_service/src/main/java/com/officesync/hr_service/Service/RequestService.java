package com.officesync.hr_service.Service;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List; // Import Role

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional; // Import thêm

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

   // --- 2. DUYỆT ĐƠN (SỬA LẠI ĐỂ REALTIME CHI TIẾT) ---

    @Transactional
    public Request approveRequest(Long requestId, Long approverId, RequestStatus newStatus, String comment) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));
        Employee approver = employeeRepository.findById(approverId)

                .orElseThrow(() -> new RuntimeException("Approver not found"));

        // Check quyền (Giữ nguyên code cũ của bạn)
        boolean isAdmin = approver.getRole() == EmployeeRole.COMPANY_ADMIN;
        boolean isManager = approver.getRole() == EmployeeRole.MANAGER;
        boolean isHrStaff = isHrEmployee(approver);
        if (!isAdmin && !isManager && !isHrStaff) {

            throw new RuntimeException("Bạn không có quyền duyệt đơn này (Yêu cầu: Admin, Manager hoặc HR)");

        }
        if (request.getStatus() != RequestStatus.PENDING) {

            throw new RuntimeException("Đơn này đã được xử lý trước đó.");

        }

        // Cập nhật
        request.setStatus(newStatus);

        request.setApprover(approver); 

        if (newStatus == RequestStatus.REJECTED) {

             request.setRejectReason(comment); 
        }
        saveAuditLog(request, approver, newStatus.name(), comment);
        Request savedRequest = requestRepository.save(request);

       // [SỬA LẠI PHẦN SOCKET]
        try {
            // 1. Gửi vào trang chi tiết (Để ai đang xem đơn này thấy ngay)
            String detailDest = "/topic/request/" + savedRequest.getId();
            messagingTemplate.convertAndSend(detailDest, savedRequest);

            // 2. Gửi cho User (Để cập nhật danh sách My Requests)
            String userDest = "/topic/user/" + savedRequest.getRequester().getId() + "/requests";
            messagingTemplate.convertAndSend(userDest, savedRequest); 

            // 3. [QUAN TRỌNG] Gửi OBJECT cho Company (Manager List)
            // Thay vì gửi chuỗi "UPDATE_REQUEST", ta gửi luôn savedRequest để Client cập nhật đè lên item cũ
            String companyDest = "/topic/company/" + savedRequest.getCompanyId() + "/requests";
            messagingTemplate.convertAndSend(companyDest, savedRequest); 
            
        } catch (Exception e) {
            log.error("Lỗi gửi WebSocket: " + e.getMessage());
        }
        return savedRequest;
    }

    // 1. Sửa hàm getRequestsForManager (Dùng cho Manager/Admin/HR)
public List<Request> getRequestsForManager(Long requesterId, String keyword, Integer day, Integer month, Integer year) {
    Employee requester = employeeRepository.findById(requesterId)
            .orElseThrow(() -> new RuntimeException("User not found"));
    
    // Xử lý keyword: Nếu rỗng thì gửi null để Query bỏ qua
    String searchKey = (keyword != null && !keyword.trim().isEmpty()) ? keyword.trim() : null;

    boolean isAdmin = requester.getRole() == EmployeeRole.COMPANY_ADMIN;
    boolean isManager = requester.getRole() == EmployeeRole.MANAGER;
    boolean isHrStaff = isHrEmployee(requester);

    // ADMIN hoặc HR -> Tìm toàn công ty
    if (isAdmin || isHrStaff) {
        return requestRepository.searchRequestsForAdmin(
            requester.getCompanyId(), searchKey, day , month, year
        );
    }
    
    // MANAGER -> Tìm trong phòng ban
    if (isManager) {
        Department dept = requester.getDepartment();
        if (dept != null) {
            return requestRepository.searchRequestsForManager(
                dept.getId(), searchKey, day , month, year
            );
        }
    }
    return Collections.emptyList();
}
    // --- Helper Check HR ---

    private boolean isHrEmployee(Employee emp) {
        // Kiểm tra nhân viên có thuộc phòng ban nào không
        if (emp.getDepartment() == null) return false;
        // Kiểm tra cờ isHr của phòng ban đó (Dùng Boolean.TRUE.equals để tránh NullPointerException)
        return Boolean.TRUE.equals(emp.getDepartment().getIsHr());
    }
   // --- 3. HỦY ĐƠN (SỬA LẠI ĐỂ REALTIME CHI TIẾT) ---

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