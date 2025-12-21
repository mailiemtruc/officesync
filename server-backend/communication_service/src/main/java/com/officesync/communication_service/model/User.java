package com.officesync.communication_service.model;

import jakarta.persistence.*;
import lombok.Data;
import org.springframework.data.domain.Persistable; // Import mới

@Entity
@Table(name = "users")
@Data

public class User implements Persistable<Long> { // ✅ Implement Persistable
    @Id
    // ❌ BỎ @GeneratedValue vì chúng ta lấy ID từ Core, không tự tạo
    private Long id;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "full_name")
    private String fullName;
    
    @Column(name = "role")
    private String role; 

    @Column(name = "company_id")
    private Long companyId;

    @Column(name = "password_hash")
    private String password;
    
    @Column(name = "avatar_url") // Nếu dùng JPA
    private String avatarUrl;
    // --- CẤU HÌNH ĐỂ FORCE INSERT ---
    
    @Transient // Không lưu trường này vào DB
    private boolean isNew = true; // Mặc định là true khi new User()

    @Override
    public boolean isNew() {
        return isNew; // Nếu true -> Hibernate sẽ INSERT. Nếu false -> UPDATE
    }

    @PrePersist
    @PostLoad
    void markNotNew() {
        this.isNew = false; // Sau khi lưu xong hoặc load từ DB lên thì không còn là mới nữa
    }
    
    // Setter thủ công để đảm bảo logic (tùy chọn, lombok @Data đã lo, nhưng viết rõ cho chắc)
    public void setId(Long id) {
        this.id = id;
    }

   public void setAvatarUrl(String avatarUrl) {
    // ✅ SỬA THÀNH:
    this.avatarUrl = avatarUrl;
}

// 3. Tạo thêm hàm getter nếu chưa có
public String getAvatarUrl() {
    return this.avatarUrl;
}
}