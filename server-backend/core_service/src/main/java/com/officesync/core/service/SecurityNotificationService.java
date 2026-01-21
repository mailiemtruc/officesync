package com.officesync.core.service;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Service
public class SecurityNotificationService {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    // Báo User bị khoá
    public void notifyUserLocked(Long userId) {
        // Topic riêng tư cho từng user: /topic/user/{id}/security
        String destination = "/topic/user/" + userId + "/security";
        
        Map<String, String> payload = Map.of(
            "type", "ACCOUNT_LOCKED",
            "message", "Your account has been locked."
        );
        
        messagingTemplate.convertAndSend(destination, payload);
        System.out.println("--> [WS-CORE] Sent LOCK signal to User ID: " + userId);
    }

    // Báo Công ty bị khoá
    public void notifyCompanyLocked(Long companyId) {
        // Topic chung cho cả công ty: /topic/company/{id}/security
        String destination = "/topic/company/" + companyId + "/security";
        
        Map<String, String> payload = Map.of(
            "type", "COMPANY_LOCKED",
            "message", "Your company has temporarily ceased operations."
        );
        
        messagingTemplate.convertAndSend(destination, payload);
        System.out.println("--> [WS-CORE] Sent LOCK signal to Company ID: " + companyId);
    }

    public void notifyLoginConflict(Long userId) {
        String destination = "/topic/user/" + userId + "/security";
        
        Map<String, String> payload = Map.of(
            "type", "LOGIN_CONFLICT", // Loại tin nhắn mới
            "message", "Your account was just logged in on a different device."
        );
        
        messagingTemplate.convertAndSend(destination, payload);
        System.out.println("--> [WS-CORE] Đã đá thiết bị cũ của User ID: " + userId);
    }
}