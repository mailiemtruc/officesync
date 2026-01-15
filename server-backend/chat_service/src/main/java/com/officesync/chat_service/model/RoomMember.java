package com.officesync.chat_service.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "room_members", 
    uniqueConstraints = @UniqueConstraint(columnNames = {"room_id", "user_id"})) // 1 người không thể vào 1 phòng 2 lần
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class RoomMember {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "room_id", nullable = false)
    private ChatRoom chatRoom;

    // ID của User (Map với bảng chat_users)
    @Column(name = "user_id", nullable = false)
    private Long userId;

    // Quyền trong nhóm
    @Enumerated(EnumType.STRING)
    @Column(name = "role")
    private GroupRole role;

    @Column(name = "joined_at")
    private LocalDateTime joinedAt;

    public enum GroupRole {
        ADMIN,  // Trưởng nhóm (có quyền kick, đổi tên)
        MEMBER  // Thành viên thường
    }
}