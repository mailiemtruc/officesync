// com.officesync.task_service.repository.TaskRepository
package com.officesync.task_service.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import com.officesync.task_service.model.Task;

public interface TaskRepository extends JpaRepository<Task, Long> {
    List<Task> findByCompanyId(Long companyId);

    List<Task> findByDepartmentId(Long departmentId);
    
    List<Task> findByAssigneeId(Long assigneeId);

    List<Task> findByCompanyIdAndPublishedTrue(Long companyId);
}
