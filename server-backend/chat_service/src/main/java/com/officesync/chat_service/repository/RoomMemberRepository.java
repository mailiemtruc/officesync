package com.officesync.chat_service.repository;

import com.officesync.chat_service.model.RoomMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface RoomMemberRepository extends JpaRepository<RoomMember, Long> {
    // Lấy tất cả thành viên trong 1 phòng
    List<RoomMember> findByChatRoomId(Long roomId);
    
    // Tìm các phòng mà user này đang tham gia (để hiển thị danh sách chat)
    List<RoomMember> findByUserId(Long userId);

    void deleteByChatRoomIdAndUserId(Long roomId, Long userId);
}