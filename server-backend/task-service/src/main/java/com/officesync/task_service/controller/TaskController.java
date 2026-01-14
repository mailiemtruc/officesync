// com.officesync.task_service.controller.TaskController.java
package com.officesync.task_service.controller;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.officesync.task_service.model.Task;
import com.officesync.task_service.model.TaskDepartment;
import com.officesync.task_service.model.TaskUser;
import com.officesync.task_service.repository.TaskDepartmentRepository;
import com.officesync.task_service.repository.TaskUserRepository;
import com.officesync.task_service.service.TaskService;

import lombok.RequiredArgsConstructor;

@RestController
@RequestMapping("/api/tasks")
@RequiredArgsConstructor
public class TaskController {

    private final TaskService taskService;
    private final TaskUserRepository userRepo;
    private final TaskDepartmentRepository deptRepo;

    @GetMapping("/me")
    public ResponseEntity<TaskUser> getCurrentUser(@RequestHeader("X-User-Id") Long userId) {
        // Logic này sẽ lấy User từ database dựa trên ID gửi từ Mobile
        TaskUser user = taskService.getOrSyncUser(userId);
        return ResponseEntity.ok(user);
    }
    @PostMapping
    public ResponseEntity<?> createTask(
            @RequestHeader("X-User-Id") Long creatorId,
            @RequestBody Task task) {
        try {
            Task created = taskService.createTask(task, creatorId);
            return ResponseEntity.ok(created);
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<Task> updateTask(@PathVariable Long id, 
                                        @RequestHeader("X-User-Id") Long requesterId,
                                        @RequestBody Task task) {
        return ResponseEntity.ok(taskService.updateTask(id, task, requesterId));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteTask(@PathVariable Long id, @RequestHeader("X-User-Id") Long requesterId) {
        try {
            taskService.deleteTask(id, requesterId);
            return ResponseEntity.ok(Map.of("message", "Deleted successfully"));
        } catch (RuntimeException e) {
            return ResponseEntity.status(403).body(Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/{id}/publish")
    public ResponseEntity<?> publishTask(@PathVariable Long id) {
        return ResponseEntity.ok(taskService.publishTask(id));
    }

    // [MỚI] API ÉP ĐỒNG BỘ (Gọi cái này nếu thấy dữ liệu thiếu)
    @PostMapping("/sync")
    public ResponseEntity<?> forceSync(@RequestHeader("X-User-Id") Long requesterId) {
        try {
            taskService.forceSyncData(requesterId);
            return ResponseEntity.ok(Map.of("message", "Data synchronized successfully from HR"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping
    public ResponseEntity<List<Task>> getTasks(@RequestHeader("X-User-Id") Long requesterId) {
        TaskUser requester = taskService.getOrSyncUser(requesterId);
        // Truyền thêm requesterId vào service để lọc theo Role
        List<Task> list = taskService.listTasksForCompany(requester.getCompanyId(), requesterId);
        return ResponseEntity.ok(list);
    }

    @GetMapping("/mine")
    public ResponseEntity<List<Task>> getMyTasks(
            @RequestHeader("X-User-Id") Long requesterId) {
        taskService.getOrSyncUser(requesterId);
        List<Task> list = taskService.listTasksForAssignee(requesterId);
        return ResponseEntity.ok(list);
    }

    @GetMapping("/departments")
    public ResponseEntity<List<TaskDepartment>> getDepartments(
            @RequestHeader("X-User-Id") Long requesterId) {
        TaskUser requester = taskService.getOrSyncUser(requesterId);
        List<TaskDepartment> depts = deptRepo.findByCompanyId(requester.getCompanyId());
        return ResponseEntity.ok(depts);
    }

    @GetMapping("/users/suggestion")
    public ResponseEntity<List<TaskUser>> suggestUsers(
            @RequestHeader("X-User-Id") Long requesterId,
            @RequestParam(defaultValue = "") String keyword) {
        
        TaskUser requester = taskService.getOrSyncUser(requesterId);
        
        // Trả về tất cả nhân viên trong CÙNG CÔNG TY
        List<TaskUser> users = userRepo.findByCompanyId(requester.getCompanyId());
        return ResponseEntity.ok(users);
    }
}