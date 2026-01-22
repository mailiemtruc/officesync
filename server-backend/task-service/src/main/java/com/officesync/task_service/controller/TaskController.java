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
        return ResponseEntity.ok(taskService.getOrSyncUser(userId));
    }

    @PostMapping
    public ResponseEntity<?> createTask(
            @RequestHeader("X-User-Id") Long creatorId,
            @RequestBody Task task) {
        try {
            return ResponseEntity.ok(taskService.createTask(task, creatorId));
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

    @GetMapping
    public ResponseEntity<List<Task>> getTasks(@RequestHeader("X-User-Id") Long requesterId) {
        TaskUser requester = taskService.getOrSyncUser(requesterId);
        List<Task> list = taskService.listTasksForCompany(requester.getCompanyId(), requesterId);
        return ResponseEntity.ok(list);
    }

    @GetMapping("/mine")
    public ResponseEntity<List<Task>> getMyTasks(@RequestHeader("X-User-Id") Long requesterId) {
        List<Task> list = taskService.listTasksForAssignee(requesterId);
        return ResponseEntity.ok(list);
    }

    @GetMapping("/departments")
    public ResponseEntity<List<TaskDepartment>> getDepartments(@RequestHeader("X-User-Id") Long requesterId) {
        TaskUser requester = taskService.getOrSyncUser(requesterId);
        return ResponseEntity.ok(deptRepo.findByCompanyId(requester.getCompanyId()));
    }

    @GetMapping("/users/suggestion")
    public ResponseEntity<List<TaskUser>> suggestUsers(
            @RequestHeader("X-User-Id") Long requesterId,
            @RequestParam(defaultValue = "") String keyword) {
        TaskUser requester = taskService.getOrSyncUser(requesterId);
        return ResponseEntity.ok(userRepo.findByCompanyId(requester.getCompanyId()));
    }
}