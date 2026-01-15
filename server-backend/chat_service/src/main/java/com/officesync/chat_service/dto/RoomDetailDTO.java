package com.officesync.chat_service.dto;

import com.officesync.chat_service.model.ChatRoom;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoomDetailDTO {
    private Long id;
    private String roomName;
    private String type;       // "PRIVATE" or "GROUP"
    private String avatarUrl;
    private Long adminId;      // Để biết ai là trưởng nhóm
    private List<MemberDTO> members; // Danh sách thành viên

    @Data
    @AllArgsConstructor
    @NoArgsConstructor
    public static class MemberDTO {
        private Long id;
        private String fullName;
        private String email;
        private String avatarUrl;
        private String role; // "ADMIN" or "MEMBER"
    }
}