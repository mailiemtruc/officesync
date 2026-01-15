package com.officesync.chat_service.controller;

import com.officesync.chat_service.dto.ChatMessageDTO;
import com.officesync.chat_service.dto.CreateGroupRequest;
import com.officesync.chat_service.model.ChatMessage;
import com.officesync.chat_service.model.ChatRoom;
import com.officesync.chat_service.model.ChatUser;
import com.officesync.chat_service.model.RoomMember;
import com.officesync.chat_service.repository.ChatMessageRepository;
import com.officesync.chat_service.repository.ChatRoomRepository;
import com.officesync.chat_service.repository.ChatUserRepository;
import com.officesync.chat_service.repository.RoomMemberRepository;
import com.officesync.chat_service.service.ChatService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.TimeZone;

@Slf4j
@RestController
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;
    private final SimpMessagingTemplate messagingTemplate;
    private final ChatMessageRepository messageRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final ChatUserRepository chatUserRepository;
    private final RoomMemberRepository roomMemberRepository; // [MỚI] Cần cái này để tìm thành viên

    // --- 1. WEBSOCKET (Đã sửa logic gửi tin & ngày tháng) ---
    @MessageMapping("/chat.sendMessage")
    public void sendMessage(@Payload ChatMessageDTO chatMessageDTO, Principal principal) {
        if (principal == null) {
            log.error("Principal is null (User chưa đăng nhập socket)");
            return;
        }
        try {
            String email = principal.getName();
            ChatUser sender = chatUserRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found: " + email));
            Long senderId = sender.getId();

            log.info("📩 Message from: {} (ID: {})", sender.getFullName(), senderId);

            // 1. Lưu tin nhắn vào DB
            ChatMessage savedMsg = chatService.saveMessage(senderId, chatMessageDTO);

            // 2. Chuẩn bị dữ liệu trả về (DTO)
            ChatMessageDTO response = new ChatMessageDTO();
            response.setContent(savedMsg.getContent());
            response.setSender(sender.getFullName()); // Tên người gửi
            
            // [QUAN TRỌNG] Format ngày tháng chuẩn ISO-8601 cho Flutter
            SimpleDateFormat isoFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
            isoFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
            response.setTimestamp(isoFormat.format(savedMsg.getTimestamp()));

            response.setType(savedMsg.getType());
            response.setRoomId(savedMsg.getRoomId());

            // [MỚI] Thêm avatar để UI hiện đẹp luôn
            // (Lưu ý: Bạn cần thêm field 'avatarUrl' vào ChatMessageDTO hoặc Client tự lấy)
            
            // 3. Gửi vào Topic chung của Phòng (Để hiện tin nhắn Real-time)
            String roomDestination = "/topic/room/" + savedMsg.getRoomId();
            messagingTemplate.convertAndSend(roomDestination, response);

            // 4. [MỚI] Gửi thông báo riêng cho từng thành viên trong phòng 
            // (Để update danh sách chat bên ngoài Sidebar - chat_socket_service.dart lắng nghe cái này)
            List<RoomMember> members = roomMemberRepository.findByChatRoomId(savedMsg.getRoomId());
            
            for (RoomMember member : members) {
                // Không gửi noti cho chính mình (tùy chọn)
                if (!member.getUserId().equals(senderId)) {
                    chatUserRepository.findById(member.getUserId()).ifPresent(u -> {
                        // Gửi vào kênh riêng: /user/{email}/queue/notifications
                        messagingTemplate.convertAndSendToUser(
                            u.getEmail(), 
                            "/queue/notifications", 
                            response 
                        );
                    });
                }
            }

        } catch (Exception e) {
            log.error("Lỗi gửi tin nhắn: ", e);
        }
    }

    // --- 2. REST API ---

    @GetMapping("/api/messages/{partnerId}")
    public ResponseEntity<?> getChatHistory(@PathVariable Long partnerId, Principal principal) {
        try {
            String email = principal.getName();
            ChatUser me = chatUserRepository.findByEmail(email).orElseThrow();
            return ResponseEntity.ok(chatService.getChatHistory(me.getId(), partnerId));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/api/conversations")
    public ResponseEntity<?> getRecentConversations(Principal principal) {
        try {
            String email = principal.getName();
            ChatUser me = chatUserRepository.findByEmail(email).orElseThrow();
            return ResponseEntity.ok(chatService.getRecentConversations(me.getId()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/api/users")
    public ResponseEntity<List<ChatUser>> getAllUsers(Principal principal) {
        if (principal == null) return ResponseEntity.status(401).build();

        String email = principal.getName();
        ChatUser me = chatUserRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        Long myId = me.getId();
        Long companyId = (me.getCompanyId() == null) ? 1L : me.getCompanyId();

        List<ChatUser> allUsers = chatUserRepository.findAll();
        
        List<ChatUser> colleagues = allUsers.stream()
                .filter(user -> {
                    boolean sameCompany = (user.getCompanyId() == null) || user.getCompanyId().equals(companyId);
                    boolean notMe = !user.getId().equals(myId);
                    return sameCompany && notMe;
                })
                .toList();

        return ResponseEntity.ok(colleagues);
    }

    @PostMapping("/api/chat/groups")
    public ResponseEntity<?> createGroup(@RequestBody CreateGroupRequest req, Principal principal) {
        try {
            String email = principal.getName();
            ChatUser me = chatUserRepository.findByEmail(email)
                    .orElseThrow(() -> new RuntimeException("User not found"));
            
            ChatRoom room = chatService.createGroupChat(me.getId(), req);
            return ResponseEntity.ok(room);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/api/chat/rooms")
    public ResponseEntity<?> getMyRooms(Principal principal) {
        String email = principal.getName();
        ChatUser me = chatUserRepository.findByEmail(email).orElseThrow();
        return ResponseEntity.ok(chatService.getMyRooms(me.getId()));
    }
    
    @PostMapping("/api/chat/private-room/{partnerId}")
    public ResponseEntity<?> getPrivateRoom(@PathVariable Long partnerId, Principal principal) {
        try {
            String email = principal.getName();
            ChatUser me = chatUserRepository.findByEmail(email).orElseThrow();
            ChatRoom room = chatService.getOrCreatePrivateRoom(me.getId(), partnerId);
            return ResponseEntity.ok(room);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
    
    @GetMapping("/api/chat/messages/{roomId}")
    public ResponseEntity<List<ChatMessage>> getMessagesByRoom(@PathVariable Long roomId) {
        List<ChatMessage> messages = messageRepository.findByRoomIdOrderByTimestampAsc(roomId);
        return ResponseEntity.ok(messages);
    }
    @GetMapping("/api/chat/room/{roomId}/info")
    public ResponseEntity<?> getRoomInfo(@PathVariable Long roomId) {
        try {
            return ResponseEntity.ok(chatService.getRoomDetails(roomId));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
}