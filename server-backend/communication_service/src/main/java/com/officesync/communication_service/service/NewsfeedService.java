package com.officesync.communication_service.service;

import com.officesync.communication_service.dto.*;
import com.officesync.communication_service.enums.ReactionType;
import com.officesync.communication_service.model.*;
import com.officesync.communication_service.repository.*;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class NewsfeedService {

    @Autowired private PostRepository postRepository;
    @Autowired private PostReactionRepository reactionRepository;
    @Autowired private PostCommentRepository commentRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private PostViewRepository viewRepository;
    @Autowired private NotificationProducer notificationProducer;
    @Autowired private SimpMessagingTemplate messagingTemplate;
    // Danh sách các vai trò được phép bắn thông báo (VIP)
    private static final List<String> VIP_ROLES = List.of("COMPANY_ADMIN", "MANAGER", "DIRECTOR");
    
    // 1. Tạo bài viết
    // 1. TẠO BÀI VIẾT (Đã tích hợp Notification cho VIP)
  public Post createPost(PostRequestDTO request, User currentUser) {
        // A. Logic Lazy Sync: Cập nhật User nếu Avatar thay đổi
        if (request.getUserAvatar() != null && !request.getUserAvatar().isEmpty()) {
            if (!request.getUserAvatar().equals(currentUser.getAvatarUrl())) {
                currentUser.setAvatarUrl(request.getUserAvatar());
                userRepository.save(currentUser); 
            }
        }

        // B. Tạo bài viết
        Post post = new Post();
        post.setContent(request.getContent());
        post.setImageUrl(request.getImageUrl());
        post.setAuthorId(currentUser.getId());
        post.setCompanyId(currentUser.getCompanyId() != null ? currentUser.getCompanyId() : 1L); 
        post.setAuthorName(currentUser.getFullName());
        post.setAuthorAvatar(currentUser.getAvatarUrl());
        
        Post savedPost = postRepository.save(post);

        // ✅ [MỚI] BẮN SOCKET REAL-TIME
        // Gửi bài mới vào kênh: /topic/company/{companyId}
        try {
            PostResponseDTO postDTO = convertToPostResponseDTO(savedPost, currentUser);
            String destination = "/topic/company/" + savedPost.getCompanyId();
            messagingTemplate.convertAndSend(destination, postDTO);
            System.out.println("--> [WebSocket] Đã bắn bài mới vào kênh: " + destination);
        } catch (Exception e) {
            System.err.println("Lỗi gửi WebSocket: " + e.getMessage());
        }

        // C. LOGIC THÔNG BÁO (NOTIFICATION SERVICE) - Giữ nguyên logic cũ
        if (VIP_ROLES.contains(currentUser.getRole())) {
            List<User> allEmployees = userRepository.findAllByCompanyId(savedPost.getCompanyId());
            for (User employee : allEmployees) {
                if (!employee.getId().equals(currentUser.getId())) {
                    NotificationEvent event = NotificationEvent.builder()
                            .userId(employee.getId())
                            .title("📢 NEW POST FROM " + currentUser.getFullName().toUpperCase())
                            .body(getShortContent(savedPost.getContent()))
                            .type("ANNOUNCEMENT")
                            .referenceId(savedPost.getId())
                            .build();
                    notificationProducer.sendNotification(event);
                }
            }
        }

        return savedPost;
    }

    // 2. Lấy danh sách bài viết (Đã sửa để luôn hiện Avatar mới nhất)
    public List<PostResponseDTO> getPosts(Long companyId, Long currentUserId) {
        List<Post> posts = postRepository.findByCompanyIdOrderByCreatedAtDesc(companyId);

        return posts.stream().map(post -> {
            Optional<PostReaction> reaction = reactionRepository.findByPostIdAndUserId(post.getId(), currentUserId);
            ReactionType myReaction = reaction.map(PostReaction::getReactionType).orElse(null);

            // ✅ SỬA ĐOẠN NÀY: Tìm thông tin tác giả mới nhất từ bảng Users
            User author = userRepository.findById(post.getAuthorId()).orElse(null);
            String latestAvatar = (author != null) ? author.getAvatarUrl() : post.getAuthorAvatar();
            String latestName = (author != null) ? author.getFullName() : post.getAuthorName();

            return PostResponseDTO.builder()
                    .id(post.getId())
                    .content(post.getContent())
                    .imageUrl(post.getImageUrl())
                    .authorId(post.getAuthorId())
                    .authorName(latestName)   // Dùng tên mới nhất
                    .authorAvatar(latestAvatar) // Dùng avatar mới nhất
                    .createdAt(post.getCreatedAt())
                    .reactionCount(reactionRepository.countByPostId(post.getId()))
                    .commentCount(commentRepository.countByPostId(post.getId()))
                    .myReaction(myReaction)
                    .build();
        }).collect(Collectors.toList());
    }

    // 3. Thả tim
    public void reactToPost(Long postId, Long userId, ReactionType type) {
        Optional<PostReaction> existing = reactionRepository.findByPostIdAndUserId(postId, userId);

        if (existing.isPresent()) {
            PostReaction reaction = existing.get();
            if (reaction.getReactionType() == type) {
                reactionRepository.delete(reaction);
            } else {
                reaction.setReactionType(type);
                reactionRepository.save(reaction);
            }
        } else {
            PostReaction newReaction = new PostReaction();
            newReaction.setPostId(postId);
            newReaction.setUserId(userId);
            newReaction.setReactionType(type);
            reactionRepository.save(newReaction);
        }
    }


// 1. Lấy danh sách comment (Đã sửa để luôn hiện Avatar mới nhất)
    public List<CommentResponseDTO> getComments(Long postId) {
        List<PostComment> comments = commentRepository.findByPostIdOrderByCreatedAtAsc(postId);

        return comments.stream().map(comment -> {
            // ✅ Luôn query User để lấy avatar mới nhất
            User user = userRepository.findById(comment.getUserId()).orElse(null);
            
            return CommentResponseDTO.builder()
                    .id(comment.getId())
                    .content(comment.getContent())
                    .parentId(comment.getParentComment() != null ? comment.getParentComment().getId() : null)
                    .userId(comment.getUserId())
                    .authorName(user != null ? user.getFullName() : "Unknown User")
                    // ✅ Lấy avatar từ bảng User (đã được đồng bộ) thay vì fix cứng
                    .authorAvatar(user != null ? user.getAvatarUrl() : "https://ui-avatars.com/api/?name=U")
                    .createdAt(comment.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());
    }

   // 2. THÊM BÌNH LUẬN (Đã tích hợp Notification cho chủ bài viết)
    public CommentResponseDTO addComment(Long postId, Long userId, CommentRequestDTO request) {
        User user = userRepository.findById(userId).orElse(null);

        // A. Logic Lazy Sync
        if (user != null && request.getUserAvatar() != null && !request.getUserAvatar().isEmpty()) {
            if (!request.getUserAvatar().equals(user.getAvatarUrl())) {
                user.setAvatarUrl(request.getUserAvatar());
                userRepository.save(user);
            }
        }

        // B. Lưu Comment
        PostComment comment = new PostComment();
        comment.setPostId(postId);
        comment.setUserId(userId);
        comment.setContent(request.getContent());

        if (request.getParentId() != null) {
            PostComment parent = commentRepository.findById(request.getParentId())
                    .orElseThrow(() -> new RuntimeException("Comment cha không tồn tại"));
            comment.setParentComment(parent);
        }

        PostComment savedComment = commentRepository.save(comment);

        // ✅ [MỚI] BẮN SOCKET REAL-TIME
        // Gửi comment mới vào kênh: /topic/post/{postId}
        try {
            CommentResponseDTO commentDTO = convertToCommentResponseDTO(savedComment, user);
            String destination = "/topic/post/" + postId;
            messagingTemplate.convertAndSend(destination, commentDTO);
            System.out.println("--> [WebSocket] Đã bắn comment mới vào kênh: " + destination);
            
            // Trả về DTO này luôn để Controller trả về Frontend (đỡ phải convert 2 lần)
            // (Nhưng logic dưới vẫn cần chạy Notification nên ta cứ để nó chạy tiếp)
        } catch (Exception e) {
             System.err.println("Lỗi gửi WebSocket: " + e.getMessage());
        }

        // C. LOGIC THÔNG BÁO (NOTIFICATION SERVICE) - Giữ nguyên logic cũ
        Post post = postRepository.findById(postId).orElse(null);
        String commenterName = (user != null) ? user.getFullName() : "Someone";

        if (post != null && !post.getAuthorId().equals(userId)) {
            NotificationEvent event = NotificationEvent.builder()
                    .userId(post.getAuthorId())
                    .title("New Comment")
                    .body(commenterName + " commented: " + getShortContent(savedComment.getContent()))
                    .type("COMMENT")
                    .referenceId(postId)
                    .build();
            notificationProducer.sendNotification(event);
        }

        // Trả về kết quả
        return convertToCommentResponseDTO(savedComment, user);
    }
    // Hàm phụ trợ: Cắt ngắn nội dung để hiển thị trên thông báo cho đẹp
    private String getShortContent(String content) {
        if (content == null || content.isEmpty()) return "sent a photo";
        return content.length() > 50 ? content.substring(0, 47) + "..." : content;
    }
    // Hàm đếm lượt xem
    public void viewPost(Long postId, Long userId) {
        // 1. Kiểm tra xem đã xem chưa để tránh spam view
        if (!viewRepository.existsByPostIdAndUserId(postId, userId)) {
            
            // 2. Lưu lịch sử xem vào bảng post_views
            PostView view = new PostView();
            view.setPostId(postId);
            view.setUserId(userId);
            viewRepository.save(view);

            // 3. Tăng viewCount trong bảng posts
            Post post = postRepository.findById(postId).orElse(null);
            if (post != null) {
                post.setViewCount(post.getViewCount() + 1);
                postRepository.save(post);
            }
        }
    }
    // ✅ [MỚI] Hàm cập nhật nhanh Avatar (Sync)
    public void syncUserAvatar(Long userId, String newAvatarUrl) {
        User user = userRepository.findById(userId).orElse(null);
        
        if (user != null) {
            // Chỉ update nếu khác nhau
            if (newAvatarUrl != null && !newAvatarUrl.equals(user.getAvatarUrl())) {
                user.setAvatarUrl(newAvatarUrl);
                userRepository.save(user);
            }
        } else {
            // Trường hợp user chưa từng tương tác, tạo mới luôn để giữ chỗ
            User newUser = new User();
            newUser.setId(userId);
            newUser.setAvatarUrl(newAvatarUrl);
            // Các trường khác có thể để null hoặc default
            userRepository.save(newUser);
        }
    }
    private PostResponseDTO convertToPostResponseDTO(Post post, User author) {
         return PostResponseDTO.builder()
                .id(post.getId())
                .content(post.getContent())
                .imageUrl(post.getImageUrl())
                .authorId(post.getAuthorId())
                .authorName(author.getFullName())
                .authorAvatar(author.getAvatarUrl())
                .createdAt(post.getCreatedAt())
                .reactionCount(0) // Mới tạo thì là 0
                .commentCount(0)
                .myReaction(null)
                .build();
    }

    private CommentResponseDTO convertToCommentResponseDTO(PostComment comment, User author) {
        return CommentResponseDTO.builder()
                .id(comment.getId())
                .content(comment.getContent())
                .parentId(comment.getParentComment() != null ? comment.getParentComment().getId() : null)
                .userId(comment.getUserId())
                .authorName(author != null ? author.getFullName() : "Unknown")
                .authorAvatar(author != null ? author.getAvatarUrl() : "")
                .createdAt(comment.getCreatedAt())
                .build();
    }
}
    
