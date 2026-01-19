package com.officesync.chat_service.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.List;

@Entity
@Table(name = "chat_rooms")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class ChatRoom {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // Tên nhóm (Null nếu là chat 1-1 Private)
    @Column(name = "room_name")
    private String roomName;

    // Phân loại phòng: PRIVATE (1-1), GROUP (Nhóm tự tạo), DEPARTMENT (Nhóm phòng ban)
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RoomType type;

    // Avatar riêng cho nhóm (nếu có)
    @Column(name = "room_avatar_url")
    private String roomAvatarUrl;

    // ID của người tạo (Admin nhóm)
    @Column(name = "admin_id")
    private Long adminId;

    // [LIÊN KẾT HR] Lưu ID phòng ban nếu đây là nhóm hệ thống
    @Column(name = "department_id")
    private Long departmentId;

    @Column(name = "created_at")
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    public enum RoomType {
        PRIVATE,    // Chat 1-1
        GROUP,      // Nhóm tùy chọn (Đi ăn, đá bóng...)
        DEPARTMENT  // Nhóm mặc định theo phòng ban công ty
    }
    @OneToMany(mappedBy = "chatRoom", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<RoomMember> members;
}