package com.officesync.task_service.service;

import com.officesync.task_service.dto.DepartmentSyncEvent;
import com.officesync.task_service.dto.EmployeeSyncEvent;
import com.officesync.task_service.model.TaskDepartment;
import com.officesync.task_service.model.TaskUser;
import com.officesync.task_service.repository.TaskDepartmentRepository;
import com.officesync.task_service.repository.TaskUserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class TaskSyncService {

    private final TaskUserRepository userRepo;
    private final TaskDepartmentRepository deptRepo;

    @Transactional
    public void upsertEmployee(EmployeeSyncEvent ev) {
        if (ev.getId() == null) return;
        TaskUser u = TaskUser.builder()
                .id(ev.getId())
                .fullName(ev.getFullName())
                .email(ev.getEmail())
                .companyId(ev.getCompanyId())
                .role(ev.getRole())
                .status(ev.getStatus())
                .departmentId(ev.getDepartmentId())
                .build();
        userRepo.save(u);
    }

    @Transactional
    public void deleteEmployee(Long id) {
        if (id == null) return;
        userRepo.deleteById(id);
    }

    @Transactional
    public void upsertDepartment(DepartmentSyncEvent ev) {
        if (ev.getId() == null) return;
        TaskDepartment d = TaskDepartment.builder()
                .id(ev.getId())
                .name(ev.getName())
                .companyId(ev.getCompanyId())
                .managerId(ev.getManagerId())
                .description(ev.getDescription()) // Thêm trường này
                .departmentCode(ev.getDepartmentCode()) // Thêm trường này
                .build();
        deptRepo.save(d);
    }

    @Transactional
    public void deleteDepartment(Long id) {
        if (id == null) return;
        deptRepo.deleteById(id);
    }
}
