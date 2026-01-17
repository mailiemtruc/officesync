package com.officesync.chat_service.service;

import com.fasterxml.jackson.databind.ObjectMapper; 
import com.officesync.chat_service.config.RabbitMQConfig; 
import com.officesync.chat_service.dto.ChatMessageDTO;
import com.officesync.chat_service.dto.CreateGroupRequest;
import com.officesync.chat_service.dto.NotificationEvent; 
import com.officesync.chat_service.dto.RoomDetailDTO;
import com.officesync.chat_service.model.ChatMessage;
import com.officesync.chat_service.model.ChatRoom;
import com.officesync.chat_service.model.ChatUser;
import com.officesync.chat_service.model.RoomMember;
import com.officesync.chat_service.repository.ChatMessageRepository;
import com.officesync.chat_service.repository.ChatRoomRepository;
import com.officesync.chat_service.repository.ChatUserRepository;
import com.officesync.chat_service.repository.RoomMemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate; 
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChatService {

    private final ChatMessageRepository messageRepository;
    private final ChatUserRepository chatUserRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final RoomMemberRepository roomMemberRepository;
    
    // [NEW] Inject RabbitMQ template and ObjectMapper
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    @Transactional
    public ChatMessage saveMessage(Long senderId, ChatMessageDTO dto) {
        // --- 1. SAVE MESSAGE LOGIC (KEEP AS IS) ---
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

        // Logic: Find/Create Private Room if roomId is missing (Backward compatibility)
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
            throw new RuntimeException("Missing valid roomId or recipientId");
        }

        message.setRoomId(finalRoomId);
        if (message.getChatId() == null) {
            message.setChatId("ROOM_" + finalRoomId);
        }

        // Update Room's 'updatedAt' timestamp
        ChatRoom room = chatRoomRepository.findById(finalRoomId).orElse(null);
        if (room != null) {
            room.setUpdatedAt(LocalDateTime.now());
            chatRoomRepository.save(room);
        }

        ChatMessage savedMsg = messageRepository.save(message);

        // --- 2. [NEW] SEND NOTIFICATION LOGIC ---
        // Can be executed asynchronously. Here we execute synchronously for data integrity.
        try {
            handleNotification(senderId, room, savedMsg);
        } catch (Exception e) {
            log.error("❌ Error sending RabbitMQ notification: {}", e.getMessage());
            // Do not throw exception to avoid rolling back the saved message
        }

        return savedMsg;
    }

    // --- NOTIFICATION HANDLING HELPER ---
    private void handleNotification(Long senderId, ChatRoom room, ChatMessage msg) {
        if (room == null) return;

        // Get Sender Name
        ChatUser sender = chatUserRepository.findById(senderId).orElse(null);
        String senderName = (sender != null) ? sender.getFullName() : "Someone";

        // SCENARIO 1: PRIVATE CHAT (1-1)
        if (room.getType() == ChatRoom.RoomType.PRIVATE) {
            // Find the other member in the room
            List<RoomMember> members = roomMemberRepository.findByChatRoomId(room.getId());
            for (RoomMember m : members) {
                if (!m.getUserId().equals(senderId)) { // Do not send to self
                    sendNotificationIfOffline(m.getUserId(), senderName, msg.getContent(), room.getId());
                }
            }
        }
        // SCENARIO 2: GROUP CHAT (GROUP / DEPARTMENT)
        else {
            String groupTitle = room.getRoomName(); 
            // Body format: "Alice: Hello everyone"
            String groupBody = senderName + ": " + msg.getContent(); 
            
            List<RoomMember> members = roomMemberRepository.findByChatRoomId(room.getId());
            for (RoomMember m : members) {
                if (!m.getUserId().equals(senderId)) {
                    sendNotificationIfOffline(m.getUserId(), groupTitle, groupBody, room.getId());
                }
            }
        }
    }

    // --- CHECK ONLINE STATUS & SEND TO RABBITMQ ---
    private void sendNotificationIfOffline(Long userId, String title, String body, Long roomId) {
        // 1. Check Online Status
        Optional<ChatUser> userOpt = chatUserRepository.findById(userId);
        if (userOpt.isPresent()) {
            ChatUser user = userOpt.get();
            
            // If Online -> SKIP (Socket already handled it)
            if (user.isOnline()) {
                log.info("⏩ User {} is Online. Notification skipped.", user.getFullName());
                return;
            }
        }

        // 2. If Offline -> Send Event to Notification Service
        try {
            NotificationEvent event = new NotificationEvent();
            event.setUserId(userId);
            event.setTitle(title);
            // Truncate body if too long
            event.setBody(body.length() > 100 ? body.substring(0, 97) + "..." : body);
            event.setType("CHAT");
            event.setReferenceId(roomId);

            // Convert Object to JSON String
            String jsonMessage = objectMapper.writeValueAsString(event);

          rabbitTemplate.convertAndSend(
    RabbitMQConfig.NOTIFICATION_EXCHANGE,
    RabbitMQConfig.NOTIFICATION_ROUTING_KEY,
    event 
);

            log.info("🚀 Notification Event sent to User ID: {}", userId);

        } catch (Exception e) {
            log.error("Error packing JSON for RabbitMQ: ", e);
        }
    }

    // --- EXISTING METHODS (UNCHANGED) ---
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

    @Transactional
    public void createDepartmentRoom(Long deptId, String deptName, Long managerId, List<Long> memberIds) {
        if (chatRoomRepository.existsByDepartmentId(deptId)) {
            log.info("⚠️ Department Chat Room for ID {} already exists. Skipped.", deptId);
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
        if (managerId != null) {
            addMemberToRoom(savedRoom, managerId, RoomMember.GroupRole.ADMIN);
        }
        if (memberIds != null && !memberIds.isEmpty()) {
            for (Long memberId : memberIds) {
                if (managerId == null || !memberId.equals(managerId)) {
                    addMemberToRoom(savedRoom, memberId, RoomMember.GroupRole.MEMBER);
                }
            }
        }
        log.info("✅ Department Chat Room created: {}", deptName);
    }

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
                .orElseThrow(() -> new RuntimeException("Room not found"));

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