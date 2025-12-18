package com.officesync.communication_service.service;

import com.officesync.communication_service.dto.*;
import com.officesync.communication_service.enums.ReactionType;
import com.officesync.communication_service.model.*;
import com.officesync.communication_service.repository.*;
import com.officesync.core.model.User; 

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

    // 4. Bình luận
    public PostComment addComment(Long postId, Long userId, CommentRequestDTO request) {
        PostComment comment = new PostComment();
        comment.setPostId(postId);
        comment.setUserId(userId);
        comment.setContent(request.getContent());

        if (request.getParentId() != null) {
            PostComment parent = commentRepository.findById(request.getParentId())
                    .orElseThrow(() -> new RuntimeException("Comment cha không tồn tại"));
            comment.setParentComment(parent);
        }

        return commentRepository.save(comment);
    }
}