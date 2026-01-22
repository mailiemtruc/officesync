package com.officesync.hr_service.Controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.officesync.hr_service.Model.Request;
import com.officesync.hr_service.Model.RequestStatus;
import com.officesync.hr_service.Service.RequestService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/requests")
@RequiredArgsConstructor
public class RequestController {

    private final RequestService requestService;

    // 1. Tạo đơn xin phép
    @PostMapping
    public ResponseEntity<Request> createRequest(
            @RequestHeader("X-User-Id") Long userId, // Lấy ID người dùng từ Header (do Gateway truyền)
            @RequestBody Request request) {
        
        Request created = requestService.createRequest(userId, request);
        return ResponseEntity.ok(created);
    }

    // 2. Duyệt đơn (Dành cho Manager/Admin)
    // URL: POST /api/v1/requests/{id}/approve
    // Body: { "status": "APPROVED", "comment": "Ok em" }
    @PostMapping("/{requestId}/process")
    public ResponseEntity<Request> processRequest(
            @PathVariable Long requestId,
            @RequestHeader("X-User-Id") Long approverId,
            @RequestBody Map<String, String> payload) {
        
        String statusStr = payload.get("status"); // APPROVED hoặc REJECTED
        String comment = payload.get("comment");
        
        RequestStatus status = RequestStatus.valueOf(statusStr);
        
        Request processed = requestService.approveRequest(requestId, approverId, status, comment);
        return ResponseEntity.ok(processed);
    }
// 2. API cho Cá nhân (My Requests)
@GetMapping
public ResponseEntity<List<Request>> getMyRequests(
        @RequestHeader("X-User-Id") Long userId,
        @RequestParam(required = false) String search, // Thêm
        @RequestParam(required = false) Integer day,   // [MỚI]
        @RequestParam(required = false) Integer month, // Thêm
        @RequestParam(required = false) Integer year   // Thêm
) {
    List<Request> requests = requestService.getMyRequests(userId, search,day, month, year);
    return ResponseEntity.ok(requests);
}

   // [SỬA] Đổi thành DeleteMapping
    @DeleteMapping("/{requestId}")
    public ResponseEntity<?> cancelRequest(
            @PathVariable Long requestId,
            @RequestHeader("X-User-Id") Long userId) {
        
        requestService.cancelRequest(requestId, userId);
        return ResponseEntity.ok(Map.of("message", "Request deleted successfully"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Request> getRequestById(@PathVariable Long id) {
        Request request = requestService.getRequestById(id);
        return ResponseEntity.ok(request);
    }


     @GetMapping("/manager")
     public ResponseEntity<List<Request>> getManagerRequests(
        @RequestHeader("X-User-Id") Long managerId,
        @RequestParam(required = false) String search,
        @RequestParam(required = false) Integer day,   // [MỚI]
        @RequestParam(required = false) Integer month,
        @RequestParam(required = false) Integer year
) {
    List<Request> requests = requestService.getRequestsForManager(managerId, search, day, month, year);
    return ResponseEntity.ok(requests);
}
}