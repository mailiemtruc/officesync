package com.officesync.communication_service.service;

import com.officesync.communication_service.dto.*;
import com.officesync.communication_service.enums.ReactionType;
import com.officesync.communication_service.model.*;
import com.officesync.communication_service.repository.*;

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
    // 1. Tạo bài viết
    public Post createPost(PostRequestDTO request, User currentUser) {
        Post post = new Post();
        post.setContent(request.getContent());
        post.setImageUrl(request.getImageUrl());
        post.setAuthorId(currentUser.getId());
        
        // Fix cứng companyId=1 nếu user chưa có hàm get
        // post.setCompanyId(currentUser.getCompanyId()); 
        post.setCompanyId(1L); 
        
        post.setAuthorName(currentUser.getEmail()); 
        post.setAuthorAvatar("https://i.pravatar.cc/150"); 
        
        return postRepository.save(post);
    }

    // 2. Lấy danh sách bài viết
    public List<PostResponseDTO> getPosts(Long companyId, Long currentUserId) {
        List<Post> posts = postRepository.findByCompanyIdOrderByCreatedAtDesc(companyId);

        return posts.stream().map(post -> {
            Optional<PostReaction> reaction = reactionRepository.findByPostIdAndUserId(post.getId(), currentUserId);
            ReactionType myReaction = reaction.map(PostReaction::getReactionType).orElse(null);

            return PostResponseDTO.builder()
                    .id(post.getId())
                    .content(post.getContent())
                    .imageUrl(post.getImageUrl())
                    .authorId(post.getAuthorId())
                    .authorName(post.getAuthorName())
                    .authorAvatar(post.getAuthorAvatar())
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


// 1. HÀM MỚI: LẤY DANH SÁCH COMMENT
    public List<CommentResponseDTO> getComments(Long postId) {
        List<PostComment> comments = commentRepository.findByPostIdOrderByCreatedAtAsc(postId);

        return comments.stream().map(comment -> {
            User user = userRepository.findById(comment.getUserId()).orElse(null);
            
            return CommentResponseDTO.builder()
                    .id(comment.getId())
                    .content(comment.getContent())
                    .parentId(comment.getParentComment() != null ? comment.getParentComment().getId() : null)
                    .userId(comment.getUserId())
                    .authorName(user != null ? user.getFullName() : "Unknown User")
                    .authorAvatar(user != null ? user.getAvatarUrl() : "https://ui-avatars.com/api/?name=U")
                    .createdAt(comment.getCreatedAt())
                    .build();
        }).collect(Collectors.toList());
    }

    // 2. CẬP NHẬT HÀM: THÊM BÌNH LUẬN (Trả về DTO)
    public CommentResponseDTO addComment(Long postId, Long userId, CommentRequestDTO request) {
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
        User user = userRepository.findById(userId).orElse(null);

        return CommentResponseDTO.builder()
                .id(savedComment.getId())
                .content(savedComment.getContent())
                .parentId(request.getParentId())
                .userId(userId)
                .authorName(user != null ? user.getFullName() : "Unknown User")
                .authorAvatar(user != null ? user.getAvatarUrl() : "https://ui-avatars.com/api/?name=U")
                .createdAt(savedComment.getCreatedAt())
                .build();
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
}