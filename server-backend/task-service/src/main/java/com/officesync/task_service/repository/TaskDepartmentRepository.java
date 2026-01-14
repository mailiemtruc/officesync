// TaskDepartmentRepository
package com.officesync.task_service.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import com.officesync.task_service.model.TaskDepartment;
import java.util.List;

public interface TaskDepartmentRepository extends JpaRepository<TaskDepartment, Long> {
    List<TaskDepartment> findByCompanyId(Long companyId);
}
