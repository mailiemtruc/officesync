package com.officesync.chat_service.repository;

import com.officesync.chat_service.model.ChatRoom;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ChatRoomRepository extends JpaRepository<ChatRoom, Long> {
    boolean existsByDepartmentId(Long departmentId);
    // Tìm phòng chat 1-1 giữa 2 người (để tránh tạo trùng)
    // Logic: Tìm phòng loại PRIVATE mà có cả user1 và user2 tham gia
    @Query("SELECT r FROM ChatRoom r " +
           "JOIN RoomMember m1 ON r.id = m1.chatRoom.id " +
           "JOIN RoomMember m2 ON r.id = m2.chatRoom.id " +
           "WHERE r.type = 'PRIVATE' " +
           "AND ((m1.userId = :user1Id AND m2.userId = :user2Id) " +
           "OR (m1.userId = :user2Id AND m2.userId = :user1Id))")
    Optional<ChatRoom> findExistingPrivateRoom(@Param("user1Id") Long user1Id, 
                                               @Param("user2Id") Long user2Id);

    // Tìm phòng chat theo Department ID (để đồng bộ từ HR)
    Optional<ChatRoom> findByDepartmentId(Long departmentId);
    
}