package com.officesync.task_service.repository;

import com.officesync.task_service.model.TaskUser;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface TaskUserRepository extends JpaRepository<TaskUser, Long> {
    List<TaskUser> findByCompanyId(Long companyId);
    List<TaskUser> findByCompanyIdAndStatus(Long companyId, String status);
    Optional<TaskUser> findByEmail(String email);
}