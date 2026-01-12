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
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable; // [1] NHỚ IMPORT CÁI NÀY
import org.springframework.cache.annotation.Caching;
import org.springframework.context.annotation.Lazy;
import org.springframework.dao.DataIntegrityViolationException; // [THÊM]
import org.springframework.stereotype.Service; // [THÊM]
import org.springframework.transaction.annotation.Transactional; // [THÊM]

import com.officesync.hr_service.Config.SnowflakeIdGenerator;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.NotificationEvent; // [1] Import cái này
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
import com.officesync.hr_service.Repository.RequestRepository; // [THÊM]

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j; // [THÊM]
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
    private final CacheManager cacheManager;
    private EmployeeService self;

    @Autowired
    public void setSelf(@Lazy EmployeeService self) {
        this.self = self;
    }
   // [MỚI] Hàm gửi thông báo (Copy từ DepartmentService sang)
    private void sendNotification(Employee receiver, String title, String body) {
        try {
            NotificationEvent event = new NotificationEvent(
                receiver.getId(),
                title,
                body,
                "SYSTEM", // Loại thông báo
                null      // ID tham chiếu
            );
            employeeProducer.sendNotification(event);
        } catch (Exception e) {
            log.error("Lỗi gửi thông báo cho user {}: {}", receiver.getId(), e.getMessage());
        }
    }
    
  private void evictDepartmentCache(Long deptId) {
        if (deptId != null) {
            try {
                // [FIX] Kiểm tra null trước khi gọi evict
                var cache = cacheManager.getCache("employees_by_department");
                if (cache != null) {
                    cache.evict(deptId);
                    log.info("--> [Cache] Đã xóa cache danh sách nhân viên phòng ban ID: {}", deptId);
                } else {
                    log.warn("--> [Cache] Không tìm thấy cache tên 'employees_by_department'");
                }
            } catch (Exception e) {
                log.warn("--> [Cache] Lỗi xóa cache deptId {}: {}", deptId, e.getMessage());
            }
        }
    }
    // [3] Viết thêm hàm hỗ trợ xóa cache SaaS
    private void evictSaaSCaches(Long companyId) {
        try {
            // Lấy vùng cache "request_list_manager"
            Cache managerCache = cacheManager.getCache("request_list_manager");
            
            if (managerCache != null) {
                // A. Tìm tất cả người có quyền duyệt trong công ty
                List<Long> approverIds = employeeRepository.findApproverIdsByCompany(companyId);
                
                // B. Xóa cache của từng người này
                for (Long approverId : approverIds) {
                    // Key format phải trùng với @Cacheable bên RequestService: "mgr_" + ID
                    managerCache.evict("mgr_" + approverId);
                }
                log.info("--> [SaaS Cache] Đã xóa cache danh sách đơn của {} người duyệt trong công ty {}", approverIds.size(), companyId);
            }
        } catch (Exception e) {
            log.error("Lỗi xóa cache SaaS: {}", e.getMessage());
        }
    }

  // --- HÀM 1: SỬA CREATE (Sửa lỗi tên biến trong annotation & Logic Manager) ---
     @Transactional
  @Caching(evict = {
    @CacheEvict(value = "departments_stats", key = "#creator.companyId"),
    @CacheEvict(value = "employees_by_company", key = "#creator.companyId")
})
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
                
                // [FIX] Vì annotation ở trên không bắt được việc departmentId bị thay đổi ở đây,
                // ta phải xóa cache thủ công cho phòng của Manager.
                evictDepartmentCache(managerDeptId);
                
                departmentId = managerDeptId; 
            } else {
                throw new RuntimeException("Lỗi: Bạn là Manager nhưng chưa thuộc phòng ban nào.");
            }
        }
        
        // 2. Các logic check trùng, gán ID giữ nguyên code cũ của bạn
        if (employeeRepository.existsByEmail(newEmployee.getEmail())) {
            throw new RuntimeException("Email " + newEmployee.getEmail() + " already exists!");
        }
        if (employeeRepository.existsByPhone(newEmployee.getPhone())) {
            throw new RuntimeException("Phone " + newEmployee.getPhone() + " already exists!");
        }

        newEmployee.setCompanyId(creator.getCompanyId());
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);
        if (newEmployee.getId() == null) newEmployee.setId(idGenerator.nextId());

        if (departmentId != null) {
            Department dept = departmentRepository.findById(departmentId)
                    .orElseThrow(() -> new RuntimeException("Phòng ban không tồn tại"));
            newEmployee.setDepartment(dept);
        }

        // 3. Lưu & Gửi MQ (Giữ nguyên code cũ)
        Employee savedEmployee = saveEmployeeWithRetry(newEmployee);
        
        if (savedEmployee != null) {
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

    // [MỚI] Hàm xử lý cập nhật trạng thái
    @Transactional
    public void updateEmployeeStatusFromEvent(UserStatusChangedEvent event) {
        log.info("--> [Core -> HR] Nhận yêu cầu đổi status. UserID: {}, Status: {}", event.getUserId(), event.getStatus());

        // 1. Tìm nhân viên theo ID
        java.util.Optional<Employee> empOpt = employeeRepository.findById(event.getUserId());

        if (empOpt.isPresent()) {
            Employee emp = empOpt.get();
            try {
                // 2. Chuyển String sang Enum và Lưu
                emp.setStatus(EmployeeStatus.valueOf(event.getStatus()));
                Employee saved = employeeRepository.save(emp);

                syncToAttendanceService(saved);
                
                log.info("--> Đã cập nhật trạng thái user {} thành {}", emp.getEmail(), event.getStatus());
            } catch (Exception e) {
                log.error("Trạng thái không hợp lệ: {}", event.getStatus());
            }
        } else {
            log.warn("Không tìm thấy nhân viên ID {} để cập nhật.", event.getUserId());
        }
    }
    // =================================================================
    // 2. LOGIC CHO RABBITMQ (Consumer gọi hàm này)
    // =================================================================
    @Transactional
    public void createEmployeeFromEvent(UserCreatedEvent event) {
        log.info("--> [Core -> HR] Nhận phản hồi đồng bộ ID. CoreID: {}, Email: {}", event.getId(), event.getEmail());

        Employee finalEmployee = null;

        // Bước 1: Tìm nhân viên hiện tại (đang giữ ID Snowflake tạm)
        Optional<Employee> existingOpt = employeeRepository.findByEmail(event.getEmail());

        if (existingOpt.isPresent()) {
            Employee existingEmp = existingOpt.get();

            // Nếu ID đã khớp nhau rồi -> Bỏ qua
            if (existingEmp.getId().equals(event.getId())) {
                return;
            }

            // --- XỬ LÝ XUNG ĐỘT (ID SWAPPING) ---
            log.info("--> PHÁT HIỆN ID TẠM ({}). TIẾN HÀNH TRÁO ĐỔI SANG ID CORE ({})", existingEmp.getId(), event.getId());

            // 1. Backup dữ liệu cũ
            Department memberOfDept = existingEmp.getDepartment(); // Phòng ban đang thuộc về (Member)
            String savedCode = existingEmp.getEmployeeCode();
            Long companyId = existingEmp.getCompanyId();

            // [QUAN TRỌNG - SỬA LỖI CONSTRAINT]
            // Kiểm tra xem nhân viên này có đang làm QUẢN LÝ (Manager) phòng nào không?
            Department managedDept = null;
            Optional<Department> deptManagedOpt = departmentRepository.findByManagerId(existingEmp.getId());
            
            if (deptManagedOpt.isPresent()) {
                managedDept = deptManagedOpt.get();
                log.info("--> Tạm thời gỡ quyền Manager khỏi phòng: {}", managedDept.getName());
                // Gỡ manager tạm thời để không bị lỗi Foreign Key khi xóa Employee
                managedDept.setManager(null);
                departmentRepository.saveAndFlush(managedDept);
            }

            // 2. Xóa bản ghi cũ (Lúc này đã an toàn để xóa)
            employeeRepository.delete(existingEmp);
            employeeRepository.flush(); // Bắt buộc flush để DB xóa ngay lập tức

            // 3. Tạo bản ghi mới với ID chuẩn từ Core
            Employee newSyncEmp = new Employee();
            newSyncEmp.setId(event.getId()); // ID Core
            
            // Restore dữ liệu
            newSyncEmp.setDepartment(memberOfDept);
            newSyncEmp.setEmployeeCode(savedCode);
            newSyncEmp.setCompanyId(companyId);

            // Map data mới nhất từ Event
            newSyncEmp.setFullName(event.getFullName());
            newSyncEmp.setEmail(event.getEmail());
            newSyncEmp.setPhone(event.getMobileNumber());
            newSyncEmp.setDateOfBirth(event.getDateOfBirth());

            try { newSyncEmp.setRole(EmployeeRole.valueOf(event.getRole())); } 
            catch (Exception e) { newSyncEmp.setRole(EmployeeRole.STAFF); }

            try { newSyncEmp.setStatus(EmployeeStatus.valueOf(event.getStatus())); } 
            catch (Exception e) { newSyncEmp.setStatus(EmployeeStatus.ACTIVE); }

            // [QUAN TRỌNG] Lưu nhân viên mới TRƯỚC
            finalEmployee = employeeRepository.saveAndFlush(newSyncEmp);

            // 4. Khôi phục chức Manager (Nếu lúc nãy có gỡ)
            if (managedDept != null) {
                log.info("--> Khôi phục quyền Manager cho phòng: {} với ID mới: {}", managedDept.getName(), newSyncEmp.getId());
                // Gán lại Manager là object nhân viên mới (đã có ID chuẩn)
                managedDept.setManager(finalEmployee);
                departmentRepository.save(managedDept);
            }

            log.info("--> ĐỒNG BỘ THÀNH CÔNG. ID cũ {} đã đổi thành {}", existingEmp.getId(), newSyncEmp.getId());

        } else {
            // Trường hợp: Tạo mới hoàn toàn (như cũ)
            finalEmployee = createFreshEmployeeFromEvent(event);
        }
        if (finalEmployee != null) {
        syncToAttendanceService(finalEmployee);
        }
    }

 
    private Employee createFreshEmployeeFromEvent(UserCreatedEvent event) {
        log.info("--> Không tìm thấy nhân viên cũ. Tạo mới hoàn toàn từ Core Event.");
        Employee newEmployee = new Employee();
        newEmployee.setId(event.getId());
        newEmployee.setCompanyId(event.getCompanyId());
        newEmployee.setFullName(event.getFullName());
        newEmployee.setEmail(event.getEmail());
        newEmployee.setDateOfBirth(event.getDateOfBirth());
        newEmployee.setPhone(event.getMobileNumber());

        try { newEmployee.setRole(EmployeeRole.valueOf(event.getRole())); } 
        catch (Exception e) { newEmployee.setRole(EmployeeRole.STAFF); }

        try { newEmployee.setStatus(EmployeeStatus.valueOf(event.getStatus())); } 
        catch (Exception e) { newEmployee.setStatus(EmployeeStatus.ACTIVE); }

        // [SỬA 2] Thêm 'return' để trả về đối tượng đã lưu
        return saveEmployeeWithRetry(newEmployee);
    }
    // =================================================================
    // 3. HÀM DÙNG CHUNG (Sinh mã & Retry)
    // =================================================================
    private Employee saveEmployeeWithRetry(Employee employee) {
        int maxRetries = 3; 
        for (int i = 0; i < maxRetries; i++) {
            try {
                // Chỉ sinh mã nếu chưa có (đề phòng trường hợp update sau này)
                if (employee.getEmployeeCode() == null) {
                    employee.setEmployeeCode(generateRandomCode());
                }
                return employeeRepository.save(employee);
            } catch (DataIntegrityViolationException e) {
                log.warn("Đụng độ mã nhân viên: {}. Thử lại lần {}...", employee.getEmployeeCode(), i + 1);
                // Reset mã để vòng lặp sau sinh mã mới
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

    // --- 3. GET LIST (TỐI ƯU CACHE ID) ---
    @Cacheable(value = "employees_by_company", key = "#companyId", sync = true)
    public List<Long> getEmployeeIdsByCompanyCached(Long companyId) {
        return employeeRepository.findIdsByCompanyId(companyId);
    }

    @Cacheable(value = "employees_by_department", key = "#deptId", sync = true)
    public List<Long> getEmployeeIdsByDepartmentCached(Long deptId) {
        return employeeRepository.findIdsByDepartmentId(deptId);
    }

    // [TỐI ƯU] Pattern: Get IDs from Cache -> Fetch Entities from DB
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

        // [SAFE] Fetch Entities (DB call tối ưu bằng WHERE IN)
        List<Employee> fetched = employeeRepository.findByIdInFetchDepartment(ids);
        
        // [SAFE] Re-order đúng thứ tự ID và lọc null (đề phòng data rác trong cache)
        Map<Long, Employee> map = fetched.stream()
            .collect(Collectors.toMap(Employee::getId, e -> e));
            
        return ids.stream()
            .map(map::get)
            .filter(Objects::nonNull) // Loại bỏ ID có trong cache nhưng không còn trong DB
            .collect(Collectors.toList());
    }

  // --- HÀM 2: SỬA UPDATE (Xóa annotation gây lỗi & dùng code thủ công) ---
    @Transactional
   @Caching(evict = {
    @CacheEvict(value = "departments_metadata", key = "#updater.companyId"),
    @CacheEvict(value = "departments_stats", key = "#updater.companyId"),
    @CacheEvict(value = "employee_detail", key = "#id"),
    @CacheEvict(value = "employees_by_company", key = "#updater.companyId")
})
    public Employee updateEmployee(
            Employee updater, Long id, String fullName, String phone, String dob, 
            String avatarUrl, String statusStr, String roleStr, Long departmentId, String email
    ) {
        // 1. Tìm nhân viên
        Employee targetEmployee = employeeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // [QUAN TRỌNG] Lấy ID phòng ban cũ để xóa cache sau khi update
        Long oldDeptId = (targetEmployee.getDepartment() != null) ? targetEmployee.getDepartment().getId() : null;
        String oldDeptName = (targetEmployee.getDepartment() != null) ? targetEmployee.getDepartment().getName() : "Unassigned";
        // 2. Logic Permission Check (Giữ nguyên code cũ)
        if (updater.getRole() == EmployeeRole.STAFF) throw new RuntimeException("Truy cập bị từ chối.");
        if (updater.getRole() == EmployeeRole.MANAGER) {
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

        EmployeeRole oldRole = targetEmployee.getRole();
        Department oldDepartment = targetEmployee.getDepartment();

        // 3. Update Fields (Giữ nguyên code cũ)
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

        // 5. Logic Sync Manager (Giữ nguyên code cũ)
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

        // [FIX] Xử lý Cache: Xóa cả phòng cũ và phòng mới (nếu có thay đổi)
        evictDepartmentCache(oldDeptId); // Refresh phòng cũ
        if (savedEmployee.getDepartment() != null) {
            Long newDeptId = savedEmployee.getDepartment().getId();
            if (!newDeptId.equals(oldDeptId)) {
                evictDepartmentCache(newDeptId); // Refresh phòng mới
            }
        }
        // 7. [MỚI - GỬI THÔNG BÁO CHUYỂN PHÒNG]
        Long currentDeptId = (savedEmployee.getDepartment() != null) ? savedEmployee.getDepartment().getId() : null;
        String currentDeptName = (savedEmployee.getDepartment() != null) ? savedEmployee.getDepartment().getName() : "Unassigned";

        // Kiểm tra xem phòng ban có thay đổi không
        if (!Objects.equals(oldDeptId, currentDeptId)) {
            String title = "Department Transfer";
            String body = "You have been transferred to department: " + currentDeptName;
            
            // Nếu bị xóa khỏi phòng (về Unassigned)
            if (currentDeptId == null) {
                body = "You have been removed from department " + oldDeptName + ". Status: Unassigned.";
            }
            
            sendNotification(savedEmployee, title, body);
            log.info("--> Đã gửi thông báo chuyển phòng cho user {}", savedEmployee.getEmail());
        }
        // 7. RabbitMQ (Giữ nguyên code cũ)
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

  @Transactional
   @Caching(evict = {
    @CacheEvict(value = "departments_stats", key = "#deleter.companyId"),
    @CacheEvict(value = "employee_detail", key = "#targetId"),
    @CacheEvict(value = "employees_by_company", key = "#deleter.companyId"),
    @CacheEvict(value = "request_list_user", key = "#targetId"),
    @CacheEvict(value = "departments_metadata", key = "#deleter.companyId"),
})
    public void deleteEmployee(Employee deleter, Long targetId) { 
        Employee targetEmployee = employeeRepository.findById(targetId)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // [FIX] Lấy ID phòng ban trước khi xóa để clear cache
        Long deptId = (targetEmployee.getDepartment() != null) ? targetEmployee.getDepartment().getId() : null;

        // 1. Permission Check (Giữ nguyên code cũ)
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

        log.info("--> Bắt đầu xóa nhân viên ID: {}", targetId);

        // 2. Logic dọn dẹp data (Giữ nguyên code cũ)
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
        evictDepartmentCache(deptId);
        evictSaaSCaches(targetEmployee.getCompanyId());
        log.info("--> XÓA THÀNH CÔNG NHÂN VIÊN ID: {}", targetId);
    }


    private void deleteOldAvatarFromStorage(String fileUrl) {
        if (fileUrl == null || fileUrl.isEmpty()) return;

        try {
            // Lấy tên file: http://.../abc.jpg -> abc.jpg
            String fileName = fileUrl.substring(fileUrl.lastIndexOf("/") + 1);

            // Gửi RabbitMQ thay vì gọi trực tiếp
            employeeProducer.sendDeleteFileEvent(fileName);
            
        } catch (Exception e) {
            log.error("Lỗi khi gửi sự kiện xóa file: {}", e.getMessage());
        }
    }
@Transactional(readOnly = true)
    public List<Employee> searchStaff(Long requesterId, String keyword) {
        // 1. Lấy thông tin người tìm
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        // 2. Gọi Repository với logic "Chọn lọc" (Active, not me, not admin)
        return employeeRepository.searchStaffForSelection(
                requester.getCompanyId(),
                requesterId, // Truyền vào để loại trừ chính mình
                keyword == null ? "" : keyword // Handle null safety
        );
    }


@Transactional(readOnly = true)
    public List<Employee> searchEmployees(Long requesterId, String keyword) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        EmployeeRole role = requester.getRole();

        // CẤP 1: ADMIN - Tìm toàn công ty
        if (role == EmployeeRole.COMPANY_ADMIN) {
             return employeeRepository.searchEmployees(requester.getCompanyId(), keyword);
        }

        // CẤP 2: MANAGER - Tìm trong phòng ban
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

        // CẤP 3: STAFF - Chỉ tìm thấy chính mình (nếu từ khóa khớp tên mình)
        // Logic: Kiểm tra keyword có nằm trong tên/mã của mình không
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
                emp.getId(), // ID NÀY ĐÃ LÀ ID CHUẨN TỪ CORE
                emp.getEmail(),
                emp.getFullName(),
                emp.getPhone(),
                emp.getDateOfBirth(),
                emp.getCompanyId(),
                emp.getRole().name(),
                emp.getStatus().name(),
                null,
                deptName
            );
            
            // Gọi hàm mới trong Producer để bắn vào Exchange nội bộ
            employeeProducer.sendToAttendance(syncEvent);
            log.info("--> [HR -> Attendance] Đã gửi thông tin User ID {} sang Attendance Service.", emp.getId());
        } catch (Exception e) {
            log.error("Lỗi đồng bộ sang Attendance: {}", e.getMessage());
        }
    }
}