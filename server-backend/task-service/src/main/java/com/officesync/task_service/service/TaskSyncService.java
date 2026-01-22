package com.officesync.task_service.service;

import com.officesync.task_service.dto.DepartmentSyncEvent;
import com.officesync.task_service.dto.EmployeeSyncEvent;
import com.officesync.task_service.model.TaskDepartment;
import com.officesync.task_service.model.TaskUser;
import com.officesync.task_service.repository.TaskDepartmentRepository;
import com.officesync.task_service.repository.TaskUserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class TaskSyncService {

    private final TaskUserRepository userRepo;
    private final TaskDepartmentRepository deptRepo;

    @Transactional
    public void upsertEmployee(EmployeeSyncEvent ev) {
        if (ev.getId() == null || ev.getEmail() == null) return;

        // 1. SELF-HEALING (Dọn rác và chuyển tiếp ID)
        List<TaskUser> existingUsers = userRepo.findAllByEmail(ev.getEmail());
        for (TaskUser oldUser : existingUsers) {
            if (!oldUser.getId().equals(ev.getId())) {
                log.info("♻️ [Self-Healing] Xóa ID rác {} và cập nhật sang ID thật {} cho email {}", 
                        oldUser.getId(), ev.getId(), ev.getEmail());
                
                // Cập nhật tất cả phòng ban đang giữ ID cũ sang ID mới
                updateManagerIdInDepartments(oldUser.getId(), ev.getId());
                
                userRepo.deleteById(oldUser.getId());
            }
        }
        userRepo.flush(); 

        // 2. LƯU USER MỚI
        TaskUser u = userRepo.findById(ev.getId()).orElse(new TaskUser());
        u.setId(ev.getId());
        u.setFullName(ev.getFullName());
        u.setEmail(ev.getEmail());
        u.setCompanyId(ev.getCompanyId());
        u.setRole(ev.getRole());
        u.setStatus(ev.getStatus());
        u.setDepartmentId(ev.getDepartmentId());

        userRepo.saveAndFlush(u);
        log.info("✅ [MQ Sync] Đồng bộ thành công User: {} (ID: {})", u.getFullName(), u.getId());

        // 3. MAGIC LINK: Tự động gán Manager vào phòng ban ngay khi User xuất hiện
        if ("MANAGER".equals(ev.getRole()) && ev.getDepartmentId() != null) {
            autoLinkManagerToDepartment(ev.getDepartmentId(), ev.getId());
        }
    }
    private void autoLinkManagerToDepartment(Long deptId, Long userId) {
        deptRepo.findById(deptId).ifPresent(dept -> {
            if (dept.getManagerId() == null || !dept.getManagerId().equals(userId)) {
                dept.setManagerId(userId);
                deptRepo.saveAndFlush(dept);
                log.info("🪄 [Auto-Link] Đã tự động gán User {} làm Quản lý cho phòng ban {}", userId, dept.getName());
            }
        });
    }

    private void updateManagerIdInDepartments(Long oldId, Long newId) {
        List<TaskDepartment> depts = deptRepo.findAllByManagerId(oldId);
        for (TaskDepartment dept : depts) {
            dept.setManagerId(newId);
            deptRepo.save(dept);
            log.info("🔗 [Self-Healing] Chuyển tiếp quyền quản lý phòng {} từ ID {} sang {}", dept.getName(), oldId, newId);
        }
    }

    @Transactional
    public void upsertDepartment(DepartmentSyncEvent ev) {
        if (ev.getDeptId() == null) return;

        TaskDepartment d = deptRepo.findById(ev.getDeptId())
                .orElse(new TaskDepartment());

        d.setId(ev.getDeptId());
        if (ev.getDeptName() != null) d.setName(ev.getDeptName());
        if (ev.getCompanyId() != null) d.setCompanyId(ev.getCompanyId());
        
        // QUAN TRỌNG: Lưu Manager ID ngay cả khi User chưa tới
        if (ev.getManagerId() != null) {
            d.setManagerId(ev.getManagerId());
        }

        deptRepo.saveAndFlush(d); // Dùng saveAndFlush để ghi xuống DB ngay lập tức
        log.info("🏢 [DB SAVE] Cập nhật phòng ban: {} (Manager ID: {})", d.getName(), d.getManagerId());
    }

    @Transactional
    public void deleteEmployee(Long id) {
        if (id == null) return;
        userRepo.deleteById(id);
    }

    @Transactional
    public void deleteDepartment(Long id) {
        if (id == null) return;
        deptRepo.deleteById(id);
        log.info("🗑️ [DB DELETE] Đã xóa phòng ban ID: {}", id);
    }
}