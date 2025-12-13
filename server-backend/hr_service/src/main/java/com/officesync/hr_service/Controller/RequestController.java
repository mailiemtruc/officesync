package com.officesync.hr_service.Controller;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
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
}