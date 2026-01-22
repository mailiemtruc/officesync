package com.officesync.hr_service.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.hibernate.Hibernate; // [BẮT BUỘC] Import này để dùng hàm unproxy
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.DTO.NotificationEvent;
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
    private final CacheManager cacheManager;

    // =========================================================================
    // 1. HELPER: QUẢN LÝ CACHE TẬP TRUNG & HIBERNATE PROXY
    // =========================================================================

    /**
     * Helper: Lột bỏ lớp vỏ Hibernate Proxy để lấy entity thật.
     * Giúp Jackson/Redis serialize được dữ liệu đầy đủ thay vì object rỗng.
     */
    @SuppressWarnings("unchecked")
    private <T> T unproxy(T entity) {
        if (entity == null) {
            return null;
        }
        return (T) Hibernate.unproxy(entity);
    }
    
    /**
     * Hàm này sẽ xóa cache của TẤT CẢ những người liên quan đến đơn từ này.
     */
    private void clearRelatedCaches(Request request) {
        try {
            Long companyId = request.getCompanyId();
            Department dept = request.getDepartment();

            // 1. Xóa cache chi tiết đơn
            var detailCache = cacheManager.getCache("request_detail");
            if (detailCache != null) {
                detailCache.evict(request.getId());
            }

            // 2. Xóa cache danh sách của người tạo (Employee)
            evictUserListCache(request.getRequester().getId());

            // 3. Xóa cache của Quản lý trực tiếp
            if (dept != null && dept.getManager() != null) {
                evictManagerListCache(dept.getManager().getId());
            }

            // 4. [QUAN TRỌNG] Xóa cache của TOÀN BỘ team HR (Manager + Staff)
            // Để đảm bảo HR luôn thấy trạng thái mới nhất (dù họ không nhận thông báo)
            Department hrDept = departmentRepository.findByCompanyIdAndIsHrTrue(companyId).orElse(null);
            if (hrDept != null) {
                List<Employee> hrEmployees = employeeRepository.findByDepartmentId(hrDept.getId());
                for (Employee hr : hrEmployees) {
                    evictManagerListCache(hr.getId());
                }
            }

            // 5. Xóa cache của TOÀN BỘ Admin
            List<Employee> admins = employeeRepository.findByCompanyIdAndRole(companyId, EmployeeRole.COMPANY_ADMIN);
            for (Employee admin : admins) {
                evictManagerListCache(admin.getId());
            }

            log.info("--> [CACHE CLEANUP] Đã xóa cache cho tất cả các bên liên quan đến Request ID: {}", request.getId());

        } catch (Exception e) {
            log.error("Lỗi khi xóa cache tập trung: {}", e.getMessage());
        }
    }

    private void evictManagerListCache(Long managerId) {
        try {
            var cache = cacheManager.getCache("request_list_manager");
            if (cache != null) {
                cache.evict("mgr_" + managerId);
            }
        } catch (Exception e) {
            log.warn("Lỗi xóa cache manager {}: {}", managerId, e.getMessage());
        }
    }

    private void evictUserListCache(Long userId) {
        try {
            var cache = cacheManager.getCache("request_list_user");
            if (cache != null) {
                cache.evict(userId);
            }
        } catch (Exception e) {
            log.warn("Lỗi xóa cache user {}: {}", userId, e.getMessage());
        }
    }

    // =========================================================================
    // 2. NGHIỆP VỤ CHÍNH
    // =========================================================================

    @Transactional
    public Request createRequest(Long userId, Request requestData) {
        // A. Lấy thông tin
        Employee requester = employeeRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        Department userDept = requester.getDepartment();
        if (userDept == null) {
            throw new RuntimeException("Lỗi: Bạn chưa thuộc về phòng ban nào.");
        }

        // B. Setup
        requestData.setRequester(requester);
        requestData.setDepartment(userDept);
        requestData.setCompanyId(requester.getCompanyId());
        requestData.setStatus(RequestStatus.PENDING);
        requestData.setCreatedAt(LocalDateTime.now());
        requestData.setUpdatedAt(LocalDateTime.now());

        // C. Lưu
        Request savedRequest = saveRequestWithRetry(requestData);

        if (savedRequest != null) {
            saveAuditLog(savedRequest, requester, "CREATED", "Request submitted successfully");
            
            // Xóa cache
            clearRelatedCaches(savedRequest);

            // Socket Realtime
            try {
                String destination = "/topic/company/" + requester.getCompanyId() + "/requests";
                messagingTemplate.convertAndSend(destination, "NEW_REQUEST");
            } catch (Exception e) {
                log.error("Lỗi gửi WS Create: {}", e.getMessage());
            }

            // Notification
            sendCreateNotification(savedRequest, requester, userDept);
        }
        return savedRequest;
    }

    @Transactional
    public Request approveRequest(Long requestId, Long approverId, RequestStatus newStatus, String comment) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));
        Employee approver = employeeRepository.findById(approverId)
                .orElseThrow(() -> new RuntimeException("Approver not found"));

        // 1. Kiểm tra chính chủ
        if (request.getRequester().getId().equals(approverId)) {
            throw new RuntimeException("Bạn không thể tự duyệt/từ chối đơn của chính mình.");
        }

        // 2. Logic phân quyền
        validateApprovalPermission(request, approver);

        // 3. Cập nhật trạng thái
        if (request.getStatus() != RequestStatus.PENDING) {
            throw new RuntimeException("Đơn này đã được xử lý trước đó.");
        }

        request.setStatus(newStatus);
        request.setApprover(approver);
        if (newStatus == RequestStatus.REJECTED) {
            request.setRejectReason(comment);
        }

        Request savedRequest = requestRepository.save(request);
        saveAuditLog(savedRequest, approver, newStatus.name(), comment);

        // Xóa cache để HR/Admin thấy update ngay lập tức (dù không nhận thông báo)
        clearRelatedCaches(savedRequest);

        // Socket update UI
        sendSocketUpdate(savedRequest);

        // Notification (Đã bỏ gửi cho HR)
        sendApprovalNotification(savedRequest, approver, newStatus);

        return savedRequest;
    }

    @Transactional
    public void cancelRequest(Long requestId, Long userId) {
        Request request = requestRepository.findById(requestId)
                .orElseThrow(() -> new RuntimeException("Request not found"));

        if (!request.getRequester().getId().equals(userId)) {
            throw new RuntimeException("Unauthorized: You do not own this request");
        }

        Long companyId = request.getCompanyId();
        Long reqId = request.getId();

        // Xóa cache
        clearRelatedCaches(request);

        // CASE 1: PENDING -> Xóa cứng
        if (request.getStatus() == RequestStatus.PENDING) {
            // Xóa file evidence
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
            // Xóa Log
            List<RequestAuditLog> logs = auditLogRepository.findByRequestIdOrderByTimestampDesc(requestId);
            if (!logs.isEmpty()) {
                auditLogRepository.deleteAll(logs);
            }
            // Xóa Request
            requestRepository.delete(request);
            log.info("--> Đã xóa vĩnh viễn đơn request ID: {}", reqId);

            // Socket báo xóa
            try {
                Request deletedPayload = new Request();
                deletedPayload.setId(reqId);
                deletedPayload.setCompanyId(companyId);
                messagingTemplate.convertAndSend("/topic/request/" + reqId, deletedPayload);
                messagingTemplate.convertAndSend("/topic/company/" + companyId + "/requests", deletedPayload);
            } catch (Exception e) {
                log.error("Lỗi gửi WebSocket Delete: " + e.getMessage());
            }
        }
        // CASE 2: Đã xử lý -> Soft Delete (Ẩn)
        else {
            request.setIsHidden(true);
            requestRepository.save(request);
            log.info("--> Đã ẩn đơn (Soft Delete) ID: {}", requestId);
        }
    }

    // =========================================================================
    // 3. GET LIST (ĐÃ FIX LỖI HIỂN THỊ "UNKNOWN" BẰNG UNPROXY)
    // =========================================================================

    @Transactional(readOnly = true)
    @Cacheable(
        value = "request_list_manager",
        key = "'mgr_' + #requesterId",
        condition = "#keyword == null && #day == null && #month == null && #year == null",
        sync = true
    )
    public List<Request> getRequestsForManager(Long requesterId, String keyword, Integer day, Integer month, Integer year) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        String searchKey = (keyword != null && !keyword.trim().isEmpty()) ? keyword.trim() : null;
        boolean isAdmin = requester.getRole() == EmployeeRole.COMPANY_ADMIN;
        boolean isManager = requester.getRole() == EmployeeRole.MANAGER;
        boolean isHrStaff = isHrEmployee(requester);

        List<Request> results = Collections.emptyList();

        // 1. ADMIN
        if (isAdmin) {
            results = requestRepository.searchRequestsForAdmin(requester.getCompanyId(), requesterId, searchKey, day, month, year);
        }
        // 2. HR
        else if (isHrStaff) {
            results = requestRepository.searchRequestsForHR(requester.getCompanyId(), requesterId, searchKey, day, month, year);
        }
        // 3. MANAGER
        else if (isManager) {
            Department dept = requester.getDepartment();
            if (dept != null) {
                results = requestRepository.searchRequestsForManager(dept.getId(), requesterId, searchKey, day, month, year);
            }
        }

        // [FIXED] UNPROXY
        if (!results.isEmpty()) {
            for (Request req : results) {
                if (req.getRequester() != null) {
                    Employee realRequester = unproxy(req.getRequester());
                    req.setRequester(realRequester);

                    if (realRequester.getDepartment() != null) {
                        Department realDept = unproxy(realRequester.getDepartment());
                        realRequester.setDepartment(realDept);
                    }
                }
                if (req.getApprover() != null) {
                    Employee realApprover = unproxy(req.getApprover());
                    req.setApprover(realApprover);
                }
            }
        }
        return results;
    }


   @Transactional(readOnly = true)
    @Cacheable(
        value = "request_list_user",
        key = "#userId",
        condition = "#keyword == null && #day == null && #month == null && #year == null",
        sync = true
    )
    public List<Request> getMyRequests(Long userId, String keyword, Integer day, Integer month, Integer year) {
        String searchKey = (keyword != null && !keyword.trim().isEmpty()) ? keyword.trim() : null;
        List<Request> results = requestRepository.searchRequestsForEmployee(userId, searchKey, day, month, year);
        
        // [FIXED] UNPROXY
        if (!results.isEmpty()) {
            for (Request req : results) {
                if (req.getRequester() != null) {
                    req.setRequester(unproxy(req.getRequester()));
                }
                if (req.getApprover() != null) {
                    req.setApprover(unproxy(req.getApprover()));
                }
            }
        }
        return results;
    }

    // =========================================================================
    // 4. PRIVATE UTILS
    // =========================================================================

    private void validateApprovalPermission(Request request, Employee approver) {
        EmployeeRole approverRole = approver.getRole();
        EmployeeRole requesterRole = request.getRequester().getRole();
        boolean isHrApprover = isHrEmployee(approver);
        boolean isAdmin = approverRole == EmployeeRole.COMPANY_ADMIN;

        if (requesterRole == EmployeeRole.MANAGER) {
            if (!isAdmin) {
                throw new RuntimeException("Chỉ Giám đốc (Admin) mới có quyền duyệt đơn của Quản lý.");
            }
        }
        else if (isHrEmployee(request.getRequester())) {
            boolean isHrManager = (approverRole == EmployeeRole.MANAGER && isHrApprover);
            if (!isAdmin && !isHrManager) {
                throw new RuntimeException("Đơn của nhân viên HR chỉ được duyệt bởi Quản lý phòng HR hoặc Giám đốc.");
            }
        }
        else {
            boolean isSameDeptManager = (approverRole == EmployeeRole.MANAGER
                    && request.getDepartment().getId().equals(approver.getDepartment().getId()));

            if (!isAdmin && !isHrApprover && !isSameDeptManager) {
                throw new RuntimeException("Bạn không có quyền duyệt đơn này.");
            }
        }
    }

    private void sendCreateNotification(Request request, Employee requester, Department userDept) {
        List<Employee> receivers = determineReceivers(requester, userDept);
        for (Employee receiver : receivers) {
            if (receiver.getId().equals(requester.getId())) continue;

            String title = "New Leave Request";
            String roleName = (requester.getRole() == EmployeeRole.MANAGER) ? "Manager " : "Employee ";
            String deptName = userDept.getName();
            String body = roleName + requester.getFullName() + " (" + deptName + ") has submitted a new request.";

            NotificationEvent event = new NotificationEvent(receiver.getId(), title, body, "REQUEST", request.getId());
            employeeProducer.sendNotification(event);
        }
    }

   // [ĐÃ CHỈNH SỬA] Hàm này đã bỏ logic gửi tin cho HR
    private void sendApprovalNotification(Request request, Employee approver, RequestStatus status) {
        Employee requester = request.getRequester();
        
        // Chỉ gửi thông báo cho CHÍNH CHỦ (Người tạo đơn)
        if (!requester.getId().equals(approver.getId())) {
            String statusEn = (status == RequestStatus.APPROVED) ? "APPROVED" : "REJECTED";
            String title = "Request Status Update";
            String body = "Your request has been " + statusEn + " by " + approver.getFullName();
            
            NotificationEvent event = new NotificationEvent(requester.getId(), title, body, "REQUEST", request.getId());
            employeeProducer.sendNotification(event);
        }
        
        // [REMOVED] Logic gửi cho HR khi đơn Manager được duyệt đã bị xóa tại đây.
    }

    private void sendSocketUpdate(Request request) {
        try {
            String detailDest = "/topic/request/" + request.getId();
            messagingTemplate.convertAndSend(detailDest, request);

            String userDest = "/topic/user/" + request.getRequester().getId() + "/requests";
            messagingTemplate.convertAndSend(userDest, request);

            String companyDest = "/topic/company/" + request.getCompanyId() + "/requests";
            messagingTemplate.convertAndSend(companyDest, request);
        } catch (Exception e) {
            log.error("Lỗi gửi WebSocket Update: " + e.getMessage());
        }
    }

    private List<Employee> determineReceivers(Employee requester, Department dept) {
        Long companyId = requester.getCompanyId();
        Set<Employee> receivers = new HashSet<>();
        
        // 1. Luôn thêm Admin
        receivers.addAll(employeeRepository.findByCompanyIdAndRole(companyId, EmployeeRole.COMPANY_ADMIN));

        // 2. Phân quyền
        if (requester.getRole() == EmployeeRole.MANAGER) {
            // Manager tạo đơn -> Chỉ Admin nhận (HR không nhận)
        } 
        else if (Boolean.TRUE.equals(dept.getIsHr())) {
            // HR staff tạo đơn -> Gửi Manager HR (Staff khác không nhận)
            if (dept.getManager() != null) {
                receivers.add(dept.getManager());
            }
        } 
        else {
            // Nhân viên thường -> Gửi Manager + Team HR
            if (dept.getManager() != null) {
                receivers.add(dept.getManager());
            }
            Department hrDept = departmentRepository.findByCompanyIdAndIsHrTrue(companyId).orElse(null);
            if (hrDept != null) {
                receivers.addAll(employeeRepository.findByDepartmentId(hrDept.getId()));
            }
        }

        return new ArrayList<>(receivers);
    }

    private Request saveRequestWithRetry(Request request) {
        int maxRetries = 3;
        for (int i = 0; i < maxRetries; i++) {
            try {
                request.setRequestCode(generateRandomRequestCode());
                return requestRepository.save(request);
            } catch (DataIntegrityViolationException e) {
                if (i == maxRetries - 1) throw new RuntimeException("Hệ thống bận, vui lòng thử lại.");
            }
        }
        return null;
    }

    private String generateRandomRequestCode() {
        String datePart = LocalDateTime.now().format(java.time.format.DateTimeFormatter.ofPattern("yyMMdd"));
        int randomNum = (int) (Math.random() * 10000);
        return "REQ" + datePart + String.format("%04d", randomNum);
    }

    private boolean isHrEmployee(Employee emp) {
        if (emp.getDepartment() == null) return false;
        return Boolean.TRUE.equals(emp.getDepartment().getIsHr());
    }

    private void saveAuditLog(Request request, Employee actor, String action, String comment) {
        try {
            RequestAuditLog log = new RequestAuditLog();
            log.setRequest(request);
            log.setActor(actor);
            log.setAction(action);
            log.setComment(comment);
            log.setTimestamp(LocalDateTime.now());
            auditLogRepository.save(log);
        } catch (Exception e) {
            log.warn("Lỗi lưu Audit Log: " + e.getMessage());
        }
    }
}