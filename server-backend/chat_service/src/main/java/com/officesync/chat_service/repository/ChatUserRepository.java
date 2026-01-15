package com.officesync.chat_service.repository;

import com.officesync.chat_service.model.ChatUser;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ChatUserRepository extends JpaRepository<ChatUser, Long> {
    Optional<ChatUser> findByEmail(String email);
    // Tìm tất cả user có cùng companyId
    List<ChatUser> findByCompanyId(Long companyId);
    
    // (Nâng cao) Tìm cùng công ty NHƯNG trừ bản thân mình ra (để khỏi chat với chính mình)
    List<ChatUser> findByCompanyIdAndIdNot(Long companyId, Long myId);
}