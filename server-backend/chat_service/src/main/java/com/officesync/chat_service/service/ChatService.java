package com.officesync.chat_service.service;

import com.officesync.chat_service.dto.ChatMessageDTO;
import com.officesync.chat_service.dto.CreateGroupRequest;
import com.officesync.chat_service.model.ChatMessage;
import com.officesync.chat_service.model.ChatRoom;
import com.officesync.chat_service.model.RoomMember;
import com.officesync.chat_service.repository.ChatMessageRepository;
import com.officesync.chat_service.repository.ChatRoomRepository;
import com.officesync.chat_service.repository.ChatUserRepository;
import com.officesync.chat_service.repository.RoomMemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j; // [THÊM] Để dùng log.info
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.officesync.chat_service.dto.RoomDetailDTO;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j // [THÊM] Annotation này tự tạo biến 'log'
public class ChatService {

    private final ChatMessageRepository messageRepository;
    private final ChatUserRepository chatUserRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final RoomMemberRepository roomMemberRepository;

    @Transactional
    public ChatMessage saveMessage(Long senderId, ChatMessageDTO dto) {
        ChatMessage message = new ChatMessage();
        message.setSenderId(senderId);
        message.setContent(dto.getContent());
        message.setTimestamp(new Date());
       if (dto.getType() != null) {
            message.setType(dto.getType());
        } else {
            message.setType(ChatMessage.MessageType.CHAT);
        }

        Long finalRoomId = dto.getRoomId();

        if (finalRoomId == null && dto.getRecipientId() != null) {
            try {
                Long recipientId = Long.parseLong(dto.getRecipientId());
                message.setRecipientId(recipientId); 
                ChatRoom privateRoom = getOrCreatePrivateRoom(senderId, recipientId);
                finalRoomId = privateRoom.getId();
            } catch (NumberFormatException e) {
                // Ignore
            }
        }

        if (finalRoomId == null) {
            throw new RuntimeException("Thiếu roomId hoặc recipientId hợp lệ");
        }

        message.setRoomId(finalRoomId);
        
        if (message.getChatId() == null) {
            message.setChatId("ROOM_" + finalRoomId);
        }

        chatRoomRepository.findById(finalRoomId).ifPresent(room -> {
            room.setUpdatedAt(LocalDateTime.now());
            chatRoomRepository.save(room);
        });

        return messageRepository.save(message);
    }

    @Transactional
    public ChatRoom createGroupChat(Long creatorId, CreateGroupRequest request) {
        ChatRoom room = ChatRoom.builder()
                .roomName(request.getGroupName())
                .type(ChatRoom.RoomType.GROUP)
                .adminId(creatorId)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        room = chatRoomRepository.save(room);

        addMemberToRoom(room, creatorId, RoomMember.GroupRole.ADMIN);

        if (request.getMemberIds() != null) {
            for (Long memberId : request.getMemberIds()) {
                if (!memberId.equals(creatorId)) {
                    addMemberToRoom(room, memberId, RoomMember.GroupRole.MEMBER);
                }
            }
        }
        return room;
    }

    public List<ChatRoom> getMyRooms(Long userId) {
        List<RoomMember> memberships = roomMemberRepository.findByUserId(userId);
        List<ChatRoom> rooms = new ArrayList<>();
        
        for (RoomMember m : memberships) {
            ChatRoom room = m.getChatRoom();
            if (room.getType() == ChatRoom.RoomType.PRIVATE) {
                List<RoomMember> members = roomMemberRepository.findByChatRoomId(room.getId());
                for (RoomMember member : members) {
                    if (!member.getUserId().equals(userId)) {
                        chatUserRepository.findById(member.getUserId()).ifPresent(u -> {
                            room.setRoomName(u.getFullName());
                            room.setRoomAvatarUrl(u.getAvatarUrl());
                        });
                        break;
                    }
                }
            }
            rooms.add(room);
        }
        rooms.sort((r1, r2) -> r2.getUpdatedAt().compareTo(r1.getUpdatedAt()));
        return rooms;
    }

    public List<ChatMessage> getChatHistory(Long myId, Long partnerId) {
        Optional<ChatRoom> privateRoom = chatRoomRepository.findExistingPrivateRoom(myId, partnerId);
        if (privateRoom.isPresent()) {
            return messageRepository.findByRoomIdOrderByTimestampAsc(privateRoom.get().getId());
        } else {
            return new ArrayList<>();
        }
    }

    public List<ChatMessage> getRecentConversations(Long userId) {
        List<ChatMessage> messages = messageRepository.findRecentConversations(userId);
        for (ChatMessage msg : messages) {
            Long partnerId;
            if (msg.getSenderId().equals(userId)) {
                partnerId = msg.getRecipientId(); 
            } else {
                partnerId = msg.getSenderId();    
            }
            if (partnerId != null) {
                chatUserRepository.findById(partnerId).ifPresent(user -> {
                    msg.setSenderName(user.getFullName());
                    msg.setAvatarUrl(user.getAvatarUrl());
                });
            }
        }
        return messages;
    }

    // [MỚI] Hàm xử lý tạo phòng ban tự động từ HR (Đã sửa lỗi Import Log)
    @Transactional
    public void createDepartmentRoom(Long deptId, String deptName, Long managerId, List<Long> memberIds) {
        if (chatRoomRepository.existsByDepartmentId(deptId)) {
            log.info("⚠️ Nhóm chat cho Department ID {} đã tồn tại. Bỏ qua.", deptId);
            return;
        }

        ChatRoom room = ChatRoom.builder()
                .roomName(deptName)
                .type(ChatRoom.RoomType.DEPARTMENT)
                .departmentId(deptId)
                .roomAvatarUrl("https://ui-avatars.com/api/?name=" + deptName.replace(" ", "+") + "&background=random") 
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        if (managerId != null) {
            room.setAdminId(managerId);
        }

        ChatRoom savedRoom = chatRoomRepository.save(room);

        // Thêm Manager
        if (managerId != null) {
            addMemberToRoom(savedRoom, managerId, RoomMember.GroupRole.ADMIN);
            log.info("   -> Đã thêm Manager (ID: {}) làm Admin.", managerId);
        }

        // Thêm Members
        if (memberIds != null && !memberIds.isEmpty()) {
            for (Long memberId : memberIds) {
                if (managerId == null || !memberId.equals(managerId)) {
                    addMemberToRoom(savedRoom, memberId, RoomMember.GroupRole.MEMBER);
                }
            }
            log.info("   -> Đã thêm {} thành viên ban đầu.", memberIds.size());
        }
        
        log.info("✅ Đã tạo xong nhóm chat: {}", deptName);
    }

    // --- PRIVATE METHODS ---

    public ChatRoom getOrCreatePrivateRoom(Long user1Id, Long user2Id) {
        Optional<ChatRoom> existingRoom = chatRoomRepository.findExistingPrivateRoom(user1Id, user2Id);
        if (existingRoom.isPresent()) {
            return existingRoom.get();
        }
        ChatRoom newRoom = ChatRoom.builder()
                .type(ChatRoom.RoomType.PRIVATE)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        newRoom = chatRoomRepository.save(newRoom);

        addMemberToRoom(newRoom, user1Id, RoomMember.GroupRole.MEMBER);
        addMemberToRoom(newRoom, user2Id, RoomMember.GroupRole.MEMBER);

        return newRoom;
    }

    // [QUAN TRỌNG] Chỉ giữ 1 hàm này thôi (đã xóa bản sao bị thừa ở cuối file)
    private void addMemberToRoom(ChatRoom room, Long userId, RoomMember.GroupRole role) {
        RoomMember member = RoomMember.builder()
                .chatRoom(room)
                .userId(userId)
                .role(role)
                .joinedAt(LocalDateTime.now())
                .build();
        roomMemberRepository.save(member);
    }

    public RoomDetailDTO getRoomDetails(Long roomId) {
        ChatRoom room = chatRoomRepository.findById(roomId)
                .orElseThrow(() -> new RuntimeException("Phòng không tồn tại"));

        List<RoomMember> members = roomMemberRepository.findByChatRoomId(roomId);
        
        List<RoomDetailDTO.MemberDTO> memberDTOs = new ArrayList<>();
        for (RoomMember m : members) {
            chatUserRepository.findById(m.getUserId()).ifPresent(u -> {
                memberDTOs.add(new RoomDetailDTO.MemberDTO(
                    u.getId(),
                    u.getFullName(),
                    u.getEmail(),
                    u.getAvatarUrl(),
                    m.getRole().toString()
                ));
            });
        }

        return new RoomDetailDTO(
            room.getId(),
            room.getRoomName(),
            room.getType().toString(),
            room.getRoomAvatarUrl(),
            room.getAdminId(),
            memberDTOs
        );
    }
}