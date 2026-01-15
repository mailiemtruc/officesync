package com.officesync.chat_service.model;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import java.util.Date;

@Entity
@Table(name = "chat_users")
public class ChatUser {
    
    @Id
    private Long id;

    private String email;
    private String fullName;
    private String avatarUrl; 
    private boolean isOnline;
   private LocalDateTime lastActiveAt;
    private Long companyId;

    // --- CONSTRUCTOR ---
    public ChatUser() {
    }

    public ChatUser(Long id, String email, String fullName, LocalDateTime lastActiveAt) {
        this.id = id;
        this.email = email;
        this.fullName = fullName;
        this.lastActiveAt = lastActiveAt;
    }

    // --- GETTER & SETTER (Thay thế cho @Data của Lombok) ---
    
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getFullName() {
        return fullName;
    }

    public void setFullName(String fullName) {
        this.fullName = fullName;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = avatarUrl;
    }

    public boolean isOnline() {
        return isOnline;
    }

    public void setOnline(boolean online) {
        isOnline = online;
    }

    public LocalDateTime getLastActiveAt() {
        return lastActiveAt;
    }
    // [CHÍNH LÀ HÀM BỊ LỖI CỦA BẠN - ĐÃ SỬA]
    public void setLastActiveAt(LocalDateTime lastActiveAt) {
        this.lastActiveAt = lastActiveAt;
    }

    public Long getCompanyId() { return companyId; }
    public void setCompanyId(Long companyId) { this.companyId = companyId; }
}