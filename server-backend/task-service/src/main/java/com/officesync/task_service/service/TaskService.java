// com.officesync.task_service.service.TaskService.java
package com.officesync.task_service.service;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;

import com.officesync.task_service.model.Task;
import com.officesync.task_service.model.TaskUser;
import com.officesync.task_service.model.TaskDepartment;
import com.officesync.task_service.model.TaskStatus;
import com.officesync.task_service.repository.TaskDepartmentRepository;
import com.officesync.task_service.repository.TaskRepository;
import com.officesync.task_service.repository.TaskUserRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.amqp.rabbit.core.RabbitTemplate;
import com.officesync.task_service.config.RabbitMQConfig;
import com.officesync.task_service.dto.NotificationEvent;

import org.springframework.messaging.simp.SimpMessagingTemplate;
@Service
@RequiredArgsConstructor
@Slf4j
public class TaskService {

    private final TaskRepository taskRepo;
    private final TaskUserRepository userRepo;
    private final TaskDepartmentRepository deptRepo;

    private final RabbitTemplate rabbitTemplate; // Tiêm RabbitTemplate để gửi tin nhắn
    private final SimpMessagingTemplate messagingTemplate;

    private final String HR_SERVICE_URL = "http://localhost:8081/api";

    // --- LOGIC TÌM HOẶC ĐỒNG BỘ ---
    public TaskUser getOrSyncUser(Long userId) {
        Optional<TaskUser> userOpt = userRepo.findById(userId);
        
        if (userOpt.isPresent()) {
            TaskUser user = userOpt.get();
            
            // Lấy danh sách phòng ban hiện có trong DB
            List<TaskDepartment> existingDepts = deptRepo.findByCompanyId(user.getCompanyId());

            // Case 1: Nếu công ty chưa có phòng ban nào -> Sync tất cả
            if (existingDepts.isEmpty()) {
                log.info("--> [Sync] Dữ liệu công ty trống. Đang đồng bộ...");
                syncAllDepartmentsInCompany(userId);
                syncAllEmployeesInCompany(userId);
            } 
            // Case 2 [FIX LỖI]: Nếu là MANAGER nhưng chưa thấy phòng mình quản lý (do lỗi null cũ) -> Sync lại Department
            else if ("MANAGER".equals(user.getRole())) {
                boolean hasManagedDept = existingDepts.stream()
                        .anyMatch(d -> userId.equals(d.getManagerId()));
                
                if (!hasManagedDept) {
                    log.info("--> [Auto-Fix] User {} là MANAGER nhưng DB đang lỗi (managerId=null). Đang tải lại Departments...", user.getFullName());
                    syncAllDepartmentsInCompany(userId);
                }
            }
            
            return user;
        }
        
        // Nếu user hoàn toàn chưa có
        return syncUserAndCompanyData(userId);
    }

    /**
     * Logic: Khi user chưa tồn tại (VD: Company Admin mới của cty 3)
     * 1. Lấy thông tin user đó từ HR.
     * 2. Dùng quyền của user đó để kéo TOÀN BỘ Department & Employee của cty đó về.
     * 3. Thực hiện tuần tự (không chạy ngầm) để đảm bảo dữ liệu có ngay lập tức.
     */
    private TaskUser syncUserAndCompanyData(Long userId) {
        log.info("--> [Sync] User ID {} chưa có. Bắt đầu đồng bộ từ HR...", userId);
        RestTemplate restTemplate = new RestTemplate();
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-User-Id", String.valueOf(userId));
        HttpEntity<String> entity = new HttpEntity<>(headers);

        try {
            // 1. Lấy thông tin bản thân User
            ResponseEntity<List> response = restTemplate.exchange(
                HR_SERVICE_URL + "/employees/search?keyword=", 
                HttpMethod.GET, entity, List.class
            );

            if (response.getBody() != null) {
                List<Map<String, Object>> employees = response.getBody();
                
                for (Map<String, Object> empData : employees) {
                    Long empId = ((Number) empData.get("id")).longValue();
                    
                    if (empId.equals(userId)) {
                        TaskUser currentUser = mapToTaskUser(empData);
                        userRepo.save(currentUser); // Lưu user hiện tại trước
                        
                        log.info("--> [Sync] Đã lưu User {}. Đang kéo dữ liệu Công ty ID {}...", currentUser.getFullName(), currentUser.getCompanyId());

                        // [QUAN TRỌNG] Gọi đồng bộ ngay lập tức (bỏ Async) để dữ liệu sẵn sàng cho UI
                        syncAllDepartmentsInCompany(userId);
                        syncAllEmployeesInCompany(userId); 
                        
                        return currentUser;
                    }
                }
            }
        } catch (Exception e) {
            log.error("Lỗi đồng bộ User {}: {}", userId, e.getMessage());
        }
        
        throw new RuntimeException("User not found in HR Service. ID: " + userId);
    }

    // Đồng bộ Departments (Xử lý lỗi JSON lồng nhau ở Manager)
    private void syncAllDepartmentsInCompany(Long requesterId) {
        try {
            log.info("--> [Sync] Đang kéo danh sách phòng ban cho requester {}...", requesterId);
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-User-Id", String.valueOf(requesterId));
            HttpEntity<String> entity = new HttpEntity<>(headers);
            
            ResponseEntity<List> response = restTemplate.exchange(
                HR_SERVICE_URL + "/departments", HttpMethod.GET, entity, List.class
            );
            
            if (response.getBody() != null) {
                List<Map<String, Object>> depts = response.getBody();
                for (Map<String, Object> d : depts) {
                    TaskDepartment dept = new TaskDepartment();
                    dept.setId(((Number) d.get("id")).longValue());
                    dept.setName((String) d.get("name"));
                    dept.setCompanyId(((Number) d.get("companyId")).longValue());
                    dept.setDepartmentCode((String) d.get("departmentCode"));

                    // Xử lý manager object từ HR
                    if (d.get("manager") != null && d.get("manager") instanceof Map) {
                        Map<String, Object> m = (Map<String, Object>) d.get("manager");
                        dept.setManagerId(((Number) m.get("id")).longValue());
                    } 
                    else if (d.get("managerId") != null) {
                        dept.setManagerId(((Number) d.get("managerId")).longValue());
                    }
                    
                    deptRepo.save(dept);
                }
                log.info("--> [Sync] Thành công: Đã lưu {} phòng ban.", depts.size());
            }
        } catch (Exception e) {
            log.error("--> [Sync ERROR] Không thể kéo Departments: {}", e.getMessage());
        }
    }

    // Đồng bộ Employees
    private void syncAllEmployeesInCompany(Long requesterId) {
        try {
            RestTemplate restTemplate = new RestTemplate();
            HttpHeaders headers = new HttpHeaders();
            headers.set("X-User-Id", String.valueOf(requesterId));
            HttpEntity<String> entity = new HttpEntity<>(headers);

            ResponseEntity<List> response = restTemplate.exchange(
                HR_SERVICE_URL + "/employees", 
                HttpMethod.GET, entity, List.class
            );

            if (response.getBody() != null) {
                List<Map<String, Object>> list = response.getBody();
                for (Map<String, Object> empData : list) {
                    try {
                        TaskUser u = mapToTaskUser(empData);
                        userRepo.save(u); 
                    } catch (Exception ex) {}
                }
                log.info("--> [Sync] Đã lưu {} nhân viên.", list.size());
            }
        } catch (Exception e) {
            log.warn("Lỗi sync Employees: {}", e.getMessage());
        }
    }

    // Helper map dữ liệu (Xử lý lỗi JSON lồng nhau ở Department)
    private TaskUser mapToTaskUser(Map<String, Object> empData) {
        Long id = ((Number) empData.get("id")).longValue();
        TaskUser u = new TaskUser();
        u.setId(id);
        u.setFullName((String) empData.get("fullName"));
        u.setEmail((String) empData.get("email"));
        u.setCompanyId(((Number) empData.get("companyId")).longValue());
        u.setRole((String) empData.get("role"));
        u.setStatus((String) empData.get("status"));
        
        // [FIX LỖI] Department trả về dạng Object, cần lấy ID bên trong
        if (empData.get("department") != null) {
            Object deptObj = empData.get("department");
            if (deptObj instanceof Map) {
                Map<String, Object> deptMap = (Map<String, Object>) deptObj;
                u.setDepartmentId(((Number) deptMap.get("id")).longValue());
            } else if (deptObj instanceof Number) {
                u.setDepartmentId(((Number) deptObj).longValue());
            }
        }
        return u;
    }

    // --- CÁC HÀM NGHIỆP VỤ ---

    public Task createTask(Task task, Long creatorId) {
        // 1. Kiểm tra và đồng bộ thông tin người tạo (Creator)
        TaskUser creator = getOrSyncUser(creatorId);

        // 2. Kiểm tra quyền hạn: Chỉ Admin hoặc Manager mới được tạo Task
        if (!"COMPANY_ADMIN".equals(creator.getRole()) && !"MANAGER".equals(creator.getRole())) {
            throw new RuntimeException("Unauthorized to create task");
        }

        // 3. Logic riêng cho Manager: Chỉ được giao việc trong phòng ban của mình
        if ("MANAGER".equals(creator.getRole())) {
            if (task.getDepartmentId() == null) {
                task.setDepartmentId(creator.getDepartmentId());
            } else if (!task.getDepartmentId().equals(creator.getDepartmentId())) {
                throw new RuntimeException("Manager can only create tasks for their own department");
            }
        }

        // 4. Lấy và lưu tên phòng ban vào Task
        if (task.getDepartmentId() != null) {
            deptRepo.findById(task.getDepartmentId())
                    .ifPresent(d -> task.setDepartmentName(d.getName()));
        }

        // 5. Thiết lập các thông tin cơ bản cho Task
        task.setCreatorId(creatorId);
        task.setCreatorName(creator.getFullName());
        task.setCreatedAt(LocalDateTime.now());
        if (task.getStatus() == null) task.setStatus(TaskStatus.TODO);
        task.setCompanyId(creator.getCompanyId());
        
        // Admin tạo thì phát hành ngay (isPublished = true), Manager tạo thì chờ duyệt/phát hành sau
        task.setPublished("COMPANY_ADMIN".equals(creator.getRole()));

        // 6. Đồng bộ tên người được giao việc (Assignee)
        if (task.getAssigneeId() != null) {
            try {
                userRepo.findById(task.getAssigneeId())
                        .ifPresent(u -> task.setAssigneeName(u.getFullName()));
            } catch (Exception e) {
                log.warn("Không tìm thấy thông tin Assignee Name cho ID: {}", task.getAssigneeId());
            }
        }

        // 7. Lưu Task vào Database
        Task savedTask = taskRepo.save(task);

        // 8. LOGIC GỬI THÔNG BÁO QUA MQ 
        // Khi Admin giao cho Manager hoặc Manager giao cho Staff
        if (savedTask.getAssigneeId() != null) {
            try {
                String title = "New task";
                String body = "Task: " + savedTask.getTitle();
                
                NotificationEvent event = NotificationEvent.builder()
                        .userId(savedTask.getAssigneeId()) // ID người nhận (Manager/Staff)
                        .title(title)
                        .body(body)
                        .type("TASK_ASSIGNED")
                        .referenceId(savedTask.getId())
                        .build();

                // Gửi tin nhắn đến Notification Service qua RabbitMQ
                rabbitTemplate.convertAndSend(
                    RabbitMQConfig.NOTIFICATION_EXCHANGE, 
                    RabbitMQConfig.NOTIFICATION_ROUTING_KEY, 
                    event
                );
                
                log.info("--> [MQ] Đã gửi thông báo giao việc cho User ID: {}", savedTask.getAssigneeId());
            } catch (Exception e) {
                // Log lỗi nhưng không làm sập luồng tạo Task chính
                log.error("Lỗi khi gửi thông báo MQ: {}", e.getMessage());
            }
        }
        // --- LOGIC REAL-TIME QUA WEBSOCKET (MỚI) ---
        if (savedTask.getAssigneeId() != null) {
            String destination = "/topic/tasks/" + savedTask.getAssigneeId();
            messagingTemplate.convertAndSend(destination, (Object) savedTask);
            log.info("--> [WebSocket] Đã đẩy Task mới tới topic: {}", destination);
        }

        return savedTask;
    }

    public void deleteTask(Long taskId, Long requesterId) {
        Task task = taskRepo.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        
        if (!task.getCreatorId().equals(requesterId)) {
            throw new RuntimeException("Bạn không có quyền xóa task này.");
        }

        Long assigneeId = task.getAssigneeId();
        taskRepo.deleteById(taskId);

        // --- LOGIC REAL-TIME QUA WEBSOCKET ---
        if (assigneeId != null) {
            String destination = "/topic/tasks/" + assigneeId;
            
            // Tạo Map dữ liệu xóa
            Map<String, Object> deletePayload = Map.of(
                "action", "DELETE",
                "taskId", taskId,
                "message", "Một công việc đã bị gỡ bỏ"
            );

            // Ép kiểu (Object) ở đây là QUAN TRỌNG NHẤT
            messagingTemplate.convertAndSend(destination, (Object) deletePayload);
            
            log.info("--> [WebSocket] Đã gửi thông báo XÓA Task tới topic: {}", destination);
        }
    }


    // Thêm hàm phát hành task
    public Task publishTask(Long taskId) {
        Task task = taskRepo.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        task.setPublished(true);
        return taskRepo.save(task);
    }

    // Cập nhật hàm lấy danh sách cho Company (Admin)
    public List<Task> listTasksForAdmin(Long companyId) {
        return taskRepo.findByCompanyIdAndPublishedTrue(companyId);
    }

    public Task updateTask(Long taskId, Task taskDetails, Long requesterId) {
        Task task = taskRepo.findById(taskId)
                .orElseThrow(() -> new RuntimeException("Task not found"));
        
        // Chỉ Admin hoặc chính người tạo mới được sửa
        task.setTitle(taskDetails.getTitle());
        task.setDescription(taskDetails.getDescription());
        task.setStatus(taskDetails.getStatus());
        task.setPriority(taskDetails.getPriority());
        task.setDueDate(taskDetails.getDueDate());
        task.setAssigneeId(taskDetails.getAssigneeId());
        
        // Cập nhật lại assigneeName nếu có thay đổi
        if (taskDetails.getAssigneeId() != null) {
            userRepo.findById(taskDetails.getAssigneeId())
                    .ifPresent(u -> task.setAssigneeName(u.getFullName()));
        }

        // Cập nhật lại tên phòng ban nếu có đổi ID
        if (taskDetails.getDepartmentId() != null) {
            task.setDepartmentId(taskDetails.getDepartmentId());
            deptRepo.findById(taskDetails.getDepartmentId())
                    .ifPresent(d -> task.setDepartmentName(d.getName()));
        }

        return taskRepo.save(task);
    }


    // Sửa hàm listTasksForCompany để phân quyền hiển thị
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
    
    // [MỚI] Hàm hỗ trợ Force Sync thủ công (Nếu cần gọi từ Controller)
    public void forceSyncData(Long userId) {
        syncUserAndCompanyData(userId);
    }
}