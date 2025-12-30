package com.officesync.communication_service.controller;

import com.officesync.communication_service.dto.*;
import com.officesync.communication_service.service.NewsfeedService;
import com.officesync.communication_service.model.User;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/newsfeed")
public class NewsfeedController {

    @Autowired
    private NewsfeedService newsfeedService;

    @PostMapping
    public ResponseEntity<?> createPost(@RequestBody PostRequestDTO request, 
                                        @AuthenticationPrincipal User currentUser) {
        return ResponseEntity.ok(newsfeedService.createPost(request, currentUser));
    }

    @GetMapping
    public ResponseEntity<?> getPosts(@AuthenticationPrincipal User currentUser) {
        Long companyId = 1L; 
        return ResponseEntity.ok(newsfeedService.getPosts(companyId, currentUser.getId()));
    }

    @PostMapping("/{postId}/react")
    public ResponseEntity<?> react(@PathVariable Long postId, 
                                   @RequestBody ReactionRequestDTO request,
                                   @AuthenticationPrincipal User currentUser) {
        newsfeedService.reactToPost(postId, currentUser.getId(), request.getType());
        return ResponseEntity.ok("Success");
    }

    
    // ✅ API MỚI: Lấy danh sách bình luận
    @GetMapping("/{postId}/comments")
    public ResponseEntity<?> getComments(@PathVariable Long postId) {
        return ResponseEntity.ok(newsfeedService.getComments(postId));
    }

    // ✅ CẬP NHẬT API: Đăng bình luận
    @PostMapping("/{postId}/comments")
    public ResponseEntity<?> comment(@PathVariable Long postId,
                                     @RequestBody CommentRequestDTO request,
                                     @AuthenticationPrincipal User currentUser) {
        return ResponseEntity.ok(newsfeedService.addComment(postId, currentUser.getId(), request));
    }
    @PostMapping("/{postId}/view")
    public ResponseEntity<?> viewPost(@PathVariable Long postId, 
                                      @AuthenticationPrincipal User currentUser) {
        newsfeedService.viewPost(postId, currentUser.getId());
        return ResponseEntity.ok("View counted");
    }
    
    @PostMapping("/sync-user")
    public ResponseEntity<?> syncUser(
            @AuthenticationPrincipal User currentUser, 
            @RequestBody Map<String, String> payload // Nhận JSON: {"avatarUrl": "..."}
    ) {
        String newAvatar = payload.get("avatarUrl");
        newsfeedService.syncUserAvatar(currentUser.getId(), newAvatar);
        return ResponseEntity.ok("Synced successfully");
    }
}