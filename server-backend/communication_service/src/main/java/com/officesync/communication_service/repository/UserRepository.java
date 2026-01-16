package com.officesync.communication_service.repository;

import com.officesync.communication_service.model.User; // Đảm bảo bạn đã có class User trong project này
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;
import java.util.List;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    // Hàm này dùng để tìm user khi Filter đọc email từ Token
    Optional<User> findByEmail(String email);
    List<User> findAllByCompanyId(Long companyId); // Thêm dòng này
}