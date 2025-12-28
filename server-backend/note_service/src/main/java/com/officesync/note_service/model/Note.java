package com.officesync.note_service.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Data;

@Entity
@Table(name = "notes")
@Data
@EntityListeners(AuditingEntityListener.class) // Tự động cập nhật thời gian
public class Note {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId; // ID người dùng (lấy từ Core)

    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "LONGTEXT")
    private String content;

    private boolean isPinned = false; // Trạng thái ghim

    @Column(length = 20)
    private String color = "0xFFFFFFFF"; // Màu nền (mặc định trắng)

    @Column(name = "pin")
    private String pin; // Lưu mã pin 6 số (nếu null nghĩa là không khóa)

    // Getter và Setter
    public String getPin() { return pin; }
    public void setPin(String pin) { this.pin = pin; }

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}