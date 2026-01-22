package com.officesync.task_service.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import com.officesync.task_service.model.*;
import com.officesync.task_service.repository.*;
import com.officesync.task_service.config.RabbitMQConfig;
import com.officesync.task_service.dto.NotificationEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;

@Service
@RequiredArgsConstructor
@Slf4j
public class TaskService {

    private final TaskRepository taskRepo;
    private final TaskUserRepository userRepo;
    private final TaskDepartmentRepository deptRepo;
    private final RabbitTemplate rabbitTemplate;
    private final SimpMessagingTemplate messagingTemplate;

    // Dữ liệu bây giờ hoàn toàn dựa vào DB cục bộ đã được MQ cập nhật tự động
    public TaskUser getOrSyncUser(Long userId) {
        return userRepo.findById(userId).orElseGet(() -> {
            log.warn("⚠️ User ID {} chưa có trong Task DB. Đang tạo tạm thời để tránh crash.", userId);
            // Trả về một User rỗng/tạm để Client vẫn load được trang nhưng chưa thấy dữ liệu đầy đủ
            return TaskUser.builder().id(userId).fullName("Đang đồng bộ...").build();
        });
    }

    public Task createTask(Task task, Long creatorId) {
        TaskUser creator = getOrSyncUser(creatorId);

        if (!"COMPANY_ADMIN".equals(creator.getRole()) && !"MANAGER".equals(creator.getRole())) {
            throw new RuntimeException("Unauthorized to create task");
        }

        if ("MANAGER".equals(creator.getRole())) {
            if (task.getDepartmentId() == null) {
                task.setDepartmentId(creator.getDepartmentId());
            } else if (!task.getDepartmentId().equals(creator.getDepartmentId())) {
                throw new RuntimeException("Manager can only create tasks for their own department");
            }
        }

        if (task.getDepartmentId() != null) {
            deptRepo.findById(task.getDepartmentId())
                    .ifPresent(d -> task.setDepartmentName(d.getName()));
        }

        task.setCreatorId(creatorId);
        task.setCreatorName(creator.getFullName());
        task.setCreatedAt(LocalDateTime.now());
        if (task.getStatus() == null) task.setStatus(TaskStatus.TODO);
        task.setCompanyId(creator.getCompanyId());
        task.setPublished("COMPANY_ADMIN".equals(creator.getRole()));

        if (task.getAssigneeId() != null) {
            userRepo.findById(task.getAssigneeId())
                    .ifPresent(u -> task.setAssigneeName(u.getFullName()));
        }

        Task savedTask = taskRepo.save(task);
        sendTaskNotifications(savedTask);
        return savedTask;
    }

    public void deleteTask(Long taskId, Long requesterId) {
        Task task = taskRepo.findById(taskId).orElseThrow();
        if (!task.getCreatorId().equals(requesterId) && !getOrSyncUser(requesterId).getRole().equals("COMPANY_ADMIN")) {
            throw new RuntimeException("No permission");
        }
        Task savedTask = taskRepo.save(task);
        sendTaskNotifications(savedTask);
        taskRepo.deleteById(taskId);
    }

    public Task updateTask(Long taskId, Task taskDetails, Long requesterId) {
        Task task = taskRepo.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        
        task.setTitle(taskDetails.getTitle());
        task.setDescription(taskDetails.getDescription());
        task.setStatus(taskDetails.getStatus());
        task.setPriority(taskDetails.getPriority());
        task.setDueDate(taskDetails.getDueDate());
        
        if (taskDetails.getAssigneeId() != null) {
            task.setAssigneeId(taskDetails.getAssigneeId());
            userRepo.findById(taskDetails.getAssigneeId())
                    .ifPresent(u -> task.setAssigneeName(u.getFullName()));
        }

        if (taskDetails.getDepartmentId() != null) {
            task.setDepartmentId(taskDetails.getDepartmentId());
            deptRepo.findById(taskDetails.getDepartmentId())
                    .ifPresent(d -> task.setDepartmentName(d.getName()));
        }

        return taskRepo.save(task);
    }

    public Task publishTask(Long taskId) {
        Task task = taskRepo.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        task.setPublished(true);
        return taskRepo.save(task);
    }

    private void sendTaskNotifications(Task savedTask) {
        if (savedTask.getAssigneeId() != null) {
            NotificationEvent event = NotificationEvent.builder()
                    .userId(savedTask.getAssigneeId())
                    .title("New task assigned")
                    .body("Task: " + savedTask.getTitle())
                    .type("TASK_ASSIGNED")
                    .referenceId(savedTask.getId())
                    .build();

            rabbitTemplate.convertAndSend(RabbitMQConfig.NOTIFICATION_EXCHANGE, RabbitMQConfig.NOTIFICATION_ROUTING_KEY, event);

            String destination = "/topic/tasks/" + savedTask.getAssigneeId();
            messagingTemplate.convertAndSend(destination, savedTask);
        }
    }

    public List<Task> listTasksForCompany(Long companyId, Long requesterId) {
        TaskUser requester = getOrSyncUser(requesterId);
        if ("COMPANY_ADMIN".equals(requester.getRole())) {
            return taskRepo.findByCompanyIdAndPublishedTrue(companyId);
        }
        return taskRepo.findByCompanyId(companyId);
    }

    public List<Task> listTasksForAssignee(Long assigneeId) {
        return taskRepo.findByAssigneeId(assigneeId);
    }

    
}