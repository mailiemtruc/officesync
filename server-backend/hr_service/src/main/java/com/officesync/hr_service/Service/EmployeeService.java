package com.officesync.hr_service.Service;

import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.context.annotation.Lazy;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.Config.SnowflakeIdGenerator;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.NotificationEvent;
import com.officesync.hr_service.DTO.UserCreatedEvent;
import com.officesync.hr_service.DTO.UserStatusChangedEvent;
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Model.EmployeeStatus;
import com.officesync.hr_service.Model.Request;
import com.officesync.hr_service.Model.RequestAuditLog;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;
import com.officesync.hr_service.Repository.RequestAuditLogRepository;
import com.officesync.hr_service.Repository.RequestRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;
    private final RequestRepository requestRepository;
    private final RequestAuditLogRepository auditLogRepository;
    private final SnowflakeIdGenerator idGenerator;
    private final EmployeeProducer employeeProducer;
    
    // [FIX] Inject CacheManager để xóa cache thủ công
    private final CacheManager cacheManager;
    
    private final SimpMessagingTemplate messagingTemplate;
    
    private EmployeeService self;

    @Autowired
    public void setSelf(@Lazy EmployeeService self) {
        this.self = self;
    }

    // =================================================================
    // CÁC HÀM QUẢN LÝ CACHE (MANUAL EVICTION)
    // =================================================================

    // 1. Xóa cache danh sách nhân viên của một phòng ban cụ thể
    private void evictDepartmentCache(Long deptId) {
        if (deptId != null) {
            try {
                var cache = cacheManager.getCache("employees_by_department");
                if (cache != null) {
                    cache.evict(deptId);
                    log.info("--> [Cache] Đã xóa cache danh sách nhân viên phòng ban ID: {}", deptId);
                }
            } catch (Exception e) {
                log.warn("--> [Cache] Lỗi xóa cache deptId {}: {}", deptId, e.getMessage());
            }
        }
    }

    // 2. [QUAN TRỌNG] Xóa cache danh sách nhân viên toàn công ty
    // Hàm này giải quyết lỗi: Tạo nhân viên xong nhưng không hiện lên list của Admin
    private void evictCompanyCache(Long companyId) {
        if (companyId != null) {
            try {
                // Xóa list ID nhân viên của công ty
                var empCache = cacheManager.getCache("employees_by_company");
                if (empCache != null) {
                    empCache.evict(companyId);
                    log.info("--> [Cache] Đã xóa cache employees_by_company ID: {}", companyId);
                }
                
                // Xóa cache thống kê phòng ban (để cập nhật số lượng member)
                var statsCache = cacheManager.getCache("departments_stats");
                if (statsCache != null) {
                    statsCache.evict(companyId);
                }
                
                // Xóa cache metadata phòng ban (nếu có)
                var metaCache = cacheManager.getCache("departments_metadata");
                if (metaCache != null) {
                    metaCache.evict(companyId);
                }
            } catch (Exception e) {
                log.warn("--> [Cache] Lỗi xóa cache companyId {}: {}", companyId, e.getMessage());
            }
        }
    }

    // 3. Xóa cache danh sách đơn từ của Manager (SaaS Cache)
    private void evictSaaSCaches(Long companyId) {
        try {
            Cache managerCache = cacheManager.getCache("request_list_manager");
            if (managerCache != null) {
                // Tìm tất cả người duyệt trong công ty để clear cache của họ
                List<Long> approverIds = employeeRepository.findApproverIdsByCompany(companyId);
                for (Long approverId : approverIds) {
                    managerCache.evict("mgr_" + approverId);
                }
            }
        } catch (Exception e) {
            log.error("Lỗi xóa cache SaaS: {}", e.getMessage());
        }
    }

    private void sendNotification(Employee receiver, String title, String body) {
        try {
            NotificationEvent event = new NotificationEvent(
                receiver.getId(), title, body, "SYSTEM", null
            );
            employeeProducer.sendNotification(event);
        } catch (Exception e) {
            log.error("Lỗi gửi thông báo: {}", e.getMessage());
        }
    }

    // =================================================================
    // 1. CREATE EMPLOYEE
    // =================================================================
    @Transactional
    public Employee createEmployee(Employee newEmployee, Employee creator, Long departmentId, String password) {
        
        // 1. Check Quyền
        EmployeeRole creatorRole = creator.getRole();
        if (creatorRole == EmployeeRole.STAFF) {
            throw new RuntimeException("Truy cập bị từ chối: Nhân viên không có quyền tạo người dùng mới.");
        }

        if (creatorRole == EmployeeRole.MANAGER) {
            newEmployee.setRole(EmployeeRole.STAFF);
            // Logic: Manager tạo nhân viên -> Tự động thêm vào phòng của Manager
            if (creator.getDepartment() != null) {
                Long managerDeptId = creator.getDepartment().getId();
                // Clear cache phòng của Manager trước khi thêm
                evictDepartmentCache(managerDeptId);
                departmentId = managerDeptId; 
            } else {
                throw new RuntimeException("Lỗi: Bạn là Manager nhưng chưa thuộc phòng ban nào.");
            }
        }
        
        // 2. Validate
        if (employeeRepository.existsByEmail(newEmployee.getEmail())) {
            throw new RuntimeException("Email " + newEmployee.getEmail() + " already exists!");
        }
        if (employeeRepository.existsByPhone(newEmployee.getPhone())) {
            throw new RuntimeException("Phone " + newEmployee.getPhone() + " already exists!");
        }

        // 3. Setup Data
        newEmployee.setCompanyId(creator.getCompanyId());
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);
        if (newEmployee.getId() == null) newEmployee.setId(idGenerator.nextId());

        if (departmentId != null) {
            Department dept = departmentRepository.findById(departmentId)
                    .orElseThrow(() -> new RuntimeException("Phòng ban không tồn tại"));
            newEmployee.setDepartment(dept);
        }

        // 4. Save
        Employee savedEmployee = saveEmployeeWithRetry(newEmployee);
        
        // [FIX - QUAN TRỌNG] Xóa cache thủ công ngay sau khi lưu
        if (savedEmployee != null) {
            evictCompanyCache(savedEmployee.getCompanyId());
            if (savedEmployee.getDepartment() != null) {
                evictDepartmentCache(savedEmployee.getDepartment().getId());
            }
            
            // 5. Send Event
            try {
                String passwordToSend = (password != null && !password.isEmpty()) ? password : "123456";
                String deptName = (savedEmployee.getDepartment() != null) ? savedEmployee.getDepartment().getName() : "N/A";

                EmployeeSyncEvent event = new EmployeeSyncEvent(
                    null, savedEmployee.getEmail(), savedEmployee.getFullName(),
                    savedEmployee.getPhone(), savedEmployee.getDateOfBirth(),
                    savedEmployee.getCompanyId(), savedEmployee.getRole().name(),
                    savedEmployee.getStatus().name(), passwordToSend, deptName
                );
                employeeProducer.sendEmployeeCreatedEvent(event);
                log.info("--> Đã gửi yêu cầu tạo User sang Core (Email: {}).", savedEmployee.getEmail());
            } catch (Exception e) {
                log.error("Lỗi gửi MQ sang Core: {}", e.getMessage());
            }
        }
        return savedEmployee;
    }

  // =================================================================
    // 2. UPDATE EMPLOYEE
    // =================================================================
    @Transactional
    public Employee updateEmployee(
            Employee updater, Long id, String fullName, String phone, String dob, 
            String avatarUrl, String statusStr, String roleStr, Long departmentId, String email
    ) {
        // 1. Tìm nhân viên
        Employee targetEmployee = employeeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // Lấy thông tin cũ để xử lý cache
        Long oldDeptId = (targetEmployee.getDepartment() != null) ? targetEmployee.getDepartment().getId() : null;
        
        // [FIX] Xác định xem có phải tự sửa chính mình không
        boolean isSelfUpdate = updater.getId().equals(targetEmployee.getId());

        // 2. Permission Check
        // [SỬA LẠI LOGIC CHẶN STAFF]
        if (updater.getRole() == EmployeeRole.STAFF && !isSelfUpdate) {
            throw new RuntimeException("Truy cập bị từ chối: Nhân viên không được phép sửa thông tin người khác.");
        }

        if (updater.getRole() == EmployeeRole.MANAGER) {
            // Manager được sửa chính mình, hoặc sửa nhân viên phòng mình
            if (!isSelfUpdate) {
                if (updater.getDepartment() == null || targetEmployee.getDepartment() == null || 
                    !updater.getDepartment().getId().equals(targetEmployee.getDepartment().getId())) {
                    throw new RuntimeException("Truy cập bị từ chối: Sai phòng ban.");
                }
                if (roleStr != null && !roleStr.isEmpty() && !roleStr.equalsIgnoreCase(targetEmployee.getRole().name())) {
                    throw new RuntimeException("Truy cập bị từ chối: Manager không được đổi Role.");
                }
                if (departmentId != null && !departmentId.equals(targetEmployee.getDepartment().getId())) {
                    throw new RuntimeException("Truy cập bị từ chối: Manager không được đổi Phòng.");
                }
            }
        }

        EmployeeRole oldRole = targetEmployee.getRole();
        Department oldDepartment = targetEmployee.getDepartment();

        // 3. Update Fields
        if (fullName != null && !fullName.isEmpty()) targetEmployee.setFullName(fullName);
        if (email != null && !email.isEmpty()) {
            if (!email.equals(targetEmployee.getEmail()) && employeeRepository.existsByEmail(email)) {
                throw new RuntimeException("Email already exists");
            }
            targetEmployee.setEmail(email);
        }
        if (phone != null && !phone.isEmpty()) {
            if (!phone.equals(targetEmployee.getPhone()) && employeeRepository.existsByPhone(phone)) {
                throw new RuntimeException("Phone already exists");
            }
            targetEmployee.setPhone(phone);
        }
        if (dob != null && !dob.isEmpty()) {
            try { targetEmployee.setDateOfBirth(LocalDate.parse(dob)); } 
            catch (Exception e) { throw new RuntimeException("Invalid Date format."); }
        }
        if (avatarUrl != null && !avatarUrl.equals(targetEmployee.getAvatarUrl())) {
            deleteOldAvatarFromStorage(targetEmployee.getAvatarUrl());
            targetEmployee.setAvatarUrl(avatarUrl);
        }
        if (statusStr != null && !statusStr.isEmpty()) {
            try { targetEmployee.setStatus(EmployeeStatus.valueOf(statusStr.toUpperCase())); } catch (Exception e) { }
        }
        if (roleStr != null && !roleStr.isEmpty()) {
            try { targetEmployee.setRole(EmployeeRole.valueOf(roleStr.toUpperCase())); } catch (Exception e) { }
        }

        // 4. Update Department
        if (departmentId != null) {
            if (departmentId == 0) {
                targetEmployee.setDepartment(null);
            } else {
                Department dept = departmentRepository.findById(departmentId).orElse(null);
                if (dept != null) targetEmployee.setDepartment(dept);
            }
        }

        // 5. Logic Sync Manager
        EmployeeRole newRole = targetEmployee.getRole();
        Department newDepartment = targetEmployee.getDepartment();

        if (oldRole == EmployeeRole.MANAGER) {
            boolean isDemoted = !newRole.equals(EmployeeRole.MANAGER);
            boolean isTransferred = (oldDepartment != null && newDepartment != null && !oldDepartment.getId().equals(newDepartment.getId()));
            boolean isLeftDept = (oldDepartment != null && newDepartment == null);

            if (isDemoted || isTransferred || isLeftDept) {
                if (oldDepartment != null && oldDepartment.getManager() != null 
                        && oldDepartment.getManager().getId().equals(targetEmployee.getId())) {
                    oldDepartment.setManager(null);
                    departmentRepository.save(oldDepartment);
                }
            }
        }
        if (newRole == EmployeeRole.MANAGER && newDepartment != null) {
            Employee currentManager = newDepartment.getManager();
            if (currentManager == null || !currentManager.getId().equals(targetEmployee.getId())) {
                newDepartment.setManager(targetEmployee);
                departmentRepository.save(newDepartment);
            }
        }

        // 6. Save
        Employee savedEmployee = employeeRepository.save(targetEmployee);

        // [FIX] Xử lý xóa Cache Thủ Công
        // Xóa cache chi tiết nhân viên
        try {
            var detailCache = cacheManager.getCache("employee_detail");
            if (detailCache != null) detailCache.evict(id);
        } catch (Exception e) {}

        // Xóa cache phòng cũ và mới
        evictDepartmentCache(oldDeptId);
        if (savedEmployee.getDepartment() != null) {
            Long newDeptId = savedEmployee.getDepartment().getId();
            if (!newDeptId.equals(oldDeptId)) {
                evictDepartmentCache(newDeptId);
            }
        }
        
        // [QUAN TRỌNG] Xóa cache list công ty (nếu đổi status/tên/role...)
        evictCompanyCache(savedEmployee.getCompanyId());

        // 7. Thông báo & Event
        Long currentDeptId = (savedEmployee.getDepartment() != null) ? savedEmployee.getDepartment().getId() : null;
        String currentDeptName = (savedEmployee.getDepartment() != null) ? savedEmployee.getDepartment().getName() : "Unassigned";
         
        if (!Objects.equals(oldDeptId, currentDeptId)) {
            String title = "Department Transfer";
            String body = "You have been transferred to department: " + currentDeptName;
            if (currentDeptId == null) {
                body = "You have been removed from department " + ((oldDepartment != null) ? oldDepartment.getName() : "Unassigned");
            }
            sendNotification(savedEmployee, title, body);
        }
        
        // Socket Refresh Profile
        try {
            String dest = "/topic/user/" + savedEmployee.getId() + "/profile";
            messagingTemplate.convertAndSend(dest, "REFRESH_PROFILE");
        } catch (Exception e) {}

        // RabbitMQ Update
        try {
            String deptName = (savedEmployee.getDepartment() != null) ? savedEmployee.getDepartment().getName() : "N/A";
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                savedEmployee.getId(), savedEmployee.getEmail(), savedEmployee.getFullName(),
                savedEmployee.getPhone(), savedEmployee.getDateOfBirth(), savedEmployee.getCompanyId(),
                savedEmployee.getRole().name(), savedEmployee.getStatus().name(), null, deptName
            );
            employeeProducer.sendEmployeeUpdatedEvent(event);
            employeeProducer.sendToAttendance(event);
        } catch (Exception e) {
            log.error("Lỗi gửi RabbitMQ: {}", e.getMessage());
        }

        return savedEmployee;
    }

    // =================================================================
    // 3. DELETE EMPLOYEE
    // =================================================================
    @Transactional
    public void deleteEmployee(Employee deleter, Long targetId) { 
        Employee targetEmployee = employeeRepository.findById(targetId)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        Long deptId = (targetEmployee.getDepartment() != null) ? targetEmployee.getDepartment().getId() : null;
        Long companyId = targetEmployee.getCompanyId();

        // 1. Permission Check
        if (deleter.getId().equals(targetId)) throw new RuntimeException("Không thể tự xóa chính mình.");
        if (!deleter.getCompanyId().equals(targetEmployee.getCompanyId())) throw new RuntimeException("Lỗi bảo mật: Khác công ty.");

        if (targetEmployee.getRole() == EmployeeRole.MANAGER) {
            if (deleter.getRole() != EmployeeRole.COMPANY_ADMIN) throw new RuntimeException("Chỉ Giám đốc mới có quyền xóa Quản lý.");
        } else {
            if (deleter.getRole() == EmployeeRole.COMPANY_ADMIN) {
                // OK
            } else if (deleter.getRole() == EmployeeRole.MANAGER) {
                if (targetEmployee.getDepartment() == null || deleter.getDepartment() == null || 
                    !targetEmployee.getDepartment().getId().equals(deleter.getDepartment().getId())) {
                    throw new RuntimeException("Chỉ được xóa nhân viên thuộc phòng ban mình quản lý.");
                }
            } else {
                throw new RuntimeException("Bạn không có quyền thực hiện thao tác này.");
            }
        }

        // 2. Logic dọn dẹp data
        Optional<Department> managedDept = departmentRepository.findByManagerId(targetId);
        if (managedDept.isPresent()) {
            Department dept = managedDept.get();
            dept.setManager(null);
            departmentRepository.save(dept);
        }

        List<Request> myRequests = requestRepository.findByRequesterId(targetId);
        for (Request req : myRequests) {
            List<RequestAuditLog> logs = auditLogRepository.findByRequestId(req.getId());
            if (!logs.isEmpty()) auditLogRepository.deleteAll(logs);
            requestRepository.delete(req);
        }

        List<Request> approvedRequests = requestRepository.findByApproverId(targetId);
        for (Request req : approvedRequests) {
            req.setApprover(null);
            requestRepository.save(req);
        }

        List<RequestAuditLog> actorLogs = auditLogRepository.findByActorId(targetId);
        if (!actorLogs.isEmpty()) auditLogRepository.deleteAll(actorLogs);

        try {
            employeeProducer.sendEmployeeDeletedEvent(targetEmployee.getId());
        } catch (Exception e) { log.error("Lỗi gửi event xóa RabbitMQ: {}", e.getMessage()); }

        // 3. Delete DB
        employeeRepository.delete(targetEmployee);

        // [FIX] Xóa cache thủ công
        try {
            var detailCache = cacheManager.getCache("employee_detail");
            if (detailCache != null) detailCache.evict(targetId);
            
            var reqCache = cacheManager.getCache("request_list_user");
            if (reqCache != null) reqCache.evict(targetId);
        } catch (Exception e) {}

        evictDepartmentCache(deptId);
        evictCompanyCache(companyId); // [QUAN TRỌNG] Xóa cache list công ty
        evictSaaSCaches(targetEmployee.getCompanyId());
        
        log.info("--> XÓA THÀNH CÔNG NHÂN VIÊN ID: {}", targetId);
    }

    // =================================================================
    // CÁC HÀM GET LIST (ĐÃ TỐI ƯU CACHE)
    // =================================================================
    
    @Cacheable(value = "employees_by_company", key = "#companyId", sync = true)
    public List<Long> getEmployeeIdsByCompanyCached(Long companyId) {
        // Nếu cache bị xóa (do create/update/delete gọi evictCompanyCache), hàm này sẽ chạy lại DB
        return employeeRepository.findIdsByCompanyId(companyId);
    }

    @Cacheable(value = "employees_by_department", key = "#deptId", sync = true)
    public List<Long> getEmployeeIdsByDepartmentCached(Long deptId) {
        return employeeRepository.findIdsByDepartmentId(deptId);
    }

    public List<Employee> getAllEmployeesByRequester(Employee requester) {
        List<Long> ids = Collections.emptyList();

        if (requester.getRole() == EmployeeRole.COMPANY_ADMIN) {
            // Gọi qua 'self' để kích hoạt Cache Proxy
            ids = self.getEmployeeIdsByCompanyCached(requester.getCompanyId());
        } else if (requester.getRole() == EmployeeRole.MANAGER) {
            if (requester.getDepartment() != null) {
                ids = self.getEmployeeIdsByDepartmentCached(requester.getDepartment().getId());
            }
        } else {
            return List.of(requester);
        }

        if (ids == null || ids.isEmpty()) return Collections.emptyList();

        List<Employee> fetched = employeeRepository.findByIdInFetchDepartment(ids);
        
        Map<Long, Employee> map = fetched.stream()
            .collect(Collectors.toMap(Employee::getId, e -> e));
            
        return ids.stream()
            .map(map::get)
            .filter(Objects::nonNull)
            .collect(Collectors.toList());
    }

    // =================================================================
    // RABBITMQ CONSUMER (SYNC TỪ CORE)
    // =================================================================
    @Transactional
    public void createEmployeeFromEvent(UserCreatedEvent event) {
        log.info("--> [Core -> HR] Nhận phản hồi đồng bộ ID. CoreID: {}, Email: {}", event.getId(), event.getEmail());

        Employee finalEmployee = null;

        // Bước 1: Tìm nhân viên hiện tại
        Optional<Employee> existingOpt = employeeRepository.findByEmail(event.getEmail());

        if (existingOpt.isPresent()) {
            Employee existingEmp = existingOpt.get();

            if (existingEmp.getId().equals(event.getId())) {
                return;
            }

            // --- ID SWAPPING ---
            log.info("--> SWAPPING ID tạm ({}) sang ID Core ({})", existingEmp.getId(), event.getId());

            // 1. Backup
            Department memberOfDept = existingEmp.getDepartment(); 
            String savedCode = existingEmp.getEmployeeCode();
            Long companyId = existingEmp.getCompanyId();

            Department managedDept = null;
            Optional<Department> deptManagedOpt = departmentRepository.findByManagerId(existingEmp.getId());
            if (deptManagedOpt.isPresent()) {
                managedDept = deptManagedOpt.get();
                managedDept.setManager(null);
                departmentRepository.saveAndFlush(managedDept);
            }

            // 2. Delete old
            employeeRepository.delete(existingEmp);
            employeeRepository.flush();

            // 3. Create new with correct ID
            Employee newSyncEmp = new Employee();
            newSyncEmp.setId(event.getId()); 
            newSyncEmp.setDepartment(memberOfDept);
            newSyncEmp.setEmployeeCode(savedCode);
            newSyncEmp.setCompanyId(companyId);

            newSyncEmp.setFullName(event.getFullName());
            newSyncEmp.setEmail(event.getEmail());
            newSyncEmp.setPhone(event.getMobileNumber());
            newSyncEmp.setDateOfBirth(event.getDateOfBirth());

            try { newSyncEmp.setRole(EmployeeRole.valueOf(event.getRole())); } 
            catch (Exception e) { newSyncEmp.setRole(EmployeeRole.STAFF); }

            try { newSyncEmp.setStatus(EmployeeStatus.valueOf(event.getStatus())); } 
            catch (Exception e) { newSyncEmp.setStatus(EmployeeStatus.ACTIVE); }

            finalEmployee = employeeRepository.saveAndFlush(newSyncEmp);

            // 4. Restore Manager
            if (managedDept != null) {
                managedDept.setManager(finalEmployee);
                departmentRepository.save(managedDept);
            }

        } else {
            // Trường hợp: Tạo mới hoàn toàn
            finalEmployee = createFreshEmployeeFromEvent(event);
        }

        if (finalEmployee != null) {
            syncToAttendanceService(finalEmployee);
            // [FIX] Xóa cache công ty để list cập nhật ID mới
            evictCompanyCache(finalEmployee.getCompanyId());
            if (finalEmployee.getDepartment() != null) {
                evictDepartmentCache(finalEmployee.getDepartment().getId());
            }
        }
    }

 
    private Employee createFreshEmployeeFromEvent(UserCreatedEvent event) {
        Employee newEmployee = new Employee();
        newEmployee.setId(event.getId());
        
        
        if (event.getCompanyId() == null && "SUPER_ADMIN".equals(event.getRole())) {
            newEmployee.setCompanyId(0L); // Gán ID = 0 để đại diện cho System/Admin
        } else {
            newEmployee.setCompanyId(event.getCompanyId());
        }

        newEmployee.setFullName(event.getFullName());
        newEmployee.setEmail(event.getEmail());
        newEmployee.setDateOfBirth(event.getDateOfBirth());
        newEmployee.setPhone(event.getMobileNumber());

        try { 
            newEmployee.setRole(EmployeeRole.valueOf(event.getRole())); 
        } catch (Exception e) { 
            // Fallback nếu role không hợp lệ
            log.error("Role không hợp lệ từ Core: {}", event.getRole());
            newEmployee.setRole(EmployeeRole.STAFF); 
        }

        try { 
            newEmployee.setStatus(EmployeeStatus.valueOf(event.getStatus())); 
        } catch (Exception e) { 
            newEmployee.setStatus(EmployeeStatus.ACTIVE); 
        }

        // Gọi hàm save có cơ chế retry (nhưng giờ sẽ không bị lỗi companyId nữa)
        Employee saved = saveEmployeeWithRetry(newEmployee);
        
        if (saved != null) {
            log.info("--> ĐÃ LƯU THÀNH CÔNG USER TỪ CORE: {} (ID: {}, Role: {})", 
                saved.getEmail(), saved.getId(), saved.getRole());
        }
        
        return saved;
    }
    
    @Transactional
    public void updateEmployeeStatusFromEvent(UserStatusChangedEvent event) {
        log.info("--> [Core -> HR] Update Status UserID: {}, Status: {}", event.getUserId(), event.getStatus());

        java.util.Optional<Employee> empOpt = employeeRepository.findById(event.getUserId());

        if (empOpt.isPresent()) {
            Employee emp = empOpt.get();
            try {
                emp.setStatus(EmployeeStatus.valueOf(event.getStatus()));
                Employee saved = employeeRepository.save(emp);

                syncToAttendanceService(saved);
                
                // [FIX] Status thay đổi (Active/Locked) có thể ảnh hưởng đến list hiển thị -> Clear cache
                evictCompanyCache(emp.getCompanyId());
                
            } catch (Exception e) {
                log.error("Trạng thái không hợp lệ: {}", event.getStatus());
            }
        }
    }

    // =================================================================
    // HÀM DÙNG CHUNG
    // =================================================================
    private Employee saveEmployeeWithRetry(Employee employee) {
        int maxRetries = 3; 
        for (int i = 0; i < maxRetries; i++) {
            try {
                if (employee.getEmployeeCode() == null) {
                    employee.setEmployeeCode(generateRandomCode());
                }
                return employeeRepository.save(employee);
            } catch (DataIntegrityViolationException e) {
                log.warn("Đụng độ mã nhân viên: {}. Thử lại lần {}...", employee.getEmployeeCode(), i + 1);
                employee.setEmployeeCode(null); 
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Lỗi hệ thống: Không thể sinh mã nhân viên.");
                }
            }
        }
        return null;
    }

    private String generateRandomCode() {
        int randomNum = (int) (Math.random() * 1000000);
        return String.format("NV%06d", randomNum);
    }
    
    private void deleteOldAvatarFromStorage(String fileUrl) {
        if (fileUrl == null || fileUrl.isEmpty()) return;
        try {
            String fileName = fileUrl.substring(fileUrl.lastIndexOf("/") + 1);
            employeeProducer.sendDeleteFileEvent(fileName);
        } catch (Exception e) {
            log.error("Lỗi khi gửi sự kiện xóa file: {}", e.getMessage());
        }
    }

    @Transactional(readOnly = true)
    public List<Employee> searchStaff(Long requesterId, String keyword) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        return employeeRepository.searchStaffForSelection(
                requester.getCompanyId(),
                requesterId,
                keyword == null ? "" : keyword 
        );
    }

    @Transactional(readOnly = true)
    public List<Employee> searchEmployees(Long requesterId, String keyword) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        EmployeeRole role = requester.getRole();

        // ADMIN
        if (role == EmployeeRole.COMPANY_ADMIN) {
             return employeeRepository.searchEmployees(requester.getCompanyId(), keyword);
        }

        // MANAGER
        if (role == EmployeeRole.MANAGER) {
            if (requester.getDepartment() != null) {
                return employeeRepository.searchEmployeesInDepartment(
                    requester.getDepartment().getId(), 
                    keyword
                );
            } else {
                return List.of(); 
            }
        }

        // STAFF
        String k = keyword.toLowerCase();
        String name = requester.getFullName().toLowerCase();
        String code = (requester.getEmployeeCode() != null) ? requester.getEmployeeCode().toLowerCase() : "";

        if (name.contains(k) || code.contains(k)) {
            return List.of(requester);
        }
        
        return List.of();
    }

    private void syncToAttendanceService(Employee emp) {
        try {
            String deptName = (emp.getDepartment() != null) ? emp.getDepartment().getName() : "N/A";
            
            EmployeeSyncEvent syncEvent = new EmployeeSyncEvent(
                emp.getId(), emp.getEmail(), emp.getFullName(),
                emp.getPhone(), emp.getDateOfBirth(),
                emp.getCompanyId(), emp.getRole().name(),
                emp.getStatus().name(), null, deptName
            );
            
            employeeProducer.sendToAttendance(syncEvent);
            log.info("--> [HR -> Attendance] Đã gửi thông tin User ID {} sang Attendance Service.", emp.getId());
        } catch (Exception e) {
            log.error("Lỗi đồng bộ sang Attendance: {}", e.getMessage());
        }
    }
}