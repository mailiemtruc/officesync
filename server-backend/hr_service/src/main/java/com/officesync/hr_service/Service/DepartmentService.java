package com.officesync.hr_service.Service;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Random;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager; // [IMPORT QUAN TRỌNG]
import org.springframework.cache.annotation.Cacheable;
import org.springframework.context.annotation.Lazy;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.NotificationEvent;
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Model.Request;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;
import com.officesync.hr_service.Repository.RequestRepository;
import com.officesync.hr_service.DTO.DepartmentSyncEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeProducer employeeProducer;
    private final RequestRepository requestRepository;
    
    // [FIX] Inject CacheManager để quản lý cache thủ công
    private final CacheManager cacheManager;
    
    private DepartmentService self;
    private final SimpMessagingTemplate messagingTemplate;

    @Autowired
    public void setSelf(@Lazy DepartmentService self) {
        this.self = self;
    }

    // =================================================================
    // CÁC HÀM QUẢN LÝ CACHE (MANUAL EVICTION)
    // =================================================================
    
    // Xóa cache liên quan đến cấu trúc công ty (Metadata, Stats, List Employees)
    private void evictCompanyStructureCache(Long companyId) {
        if (companyId == null) return;
        try {
            // 1. Metadata phòng ban (List department bên trái)
            var metaCache = cacheManager.getCache("departments_metadata");
            if (metaCache != null) metaCache.evict(companyId);

            // 2. Thống kê số lượng nhân viên (Số hiển thị trên card phòng ban)
            var statsCache = cacheManager.getCache("departments_stats");
            if (statsCache != null) statsCache.evict(companyId);

            // 3. Danh sách nhân viên toàn công ty (Admin view)
            var empCache = cacheManager.getCache("employees_by_company");
            if (empCache != null) empCache.evict(companyId);

            log.info("--> [Cache] Đã xóa cache cấu trúc công ty ID: {}", companyId);
        } catch (Exception e) {
            log.warn("--> [Cache] Lỗi xóa cache companyId {}: {}", companyId, e.getMessage());
        }
    }

    // Xóa cache thành viên của 1 phòng ban cụ thể
    private void evictDepartmentMembersCache(Long deptId) {
        if (deptId == null) return;
        try {
            var cache = cacheManager.getCache("employees_by_department");
            if (cache != null) cache.evict(deptId);
        } catch (Exception e) {
            log.warn("Lỗi xóa cache dept members: {}", e.getMessage());
        }
    }

    // [BẢO MẬT] Hàm check quyền dùng chung
    private void requireAdminRole(Employee actor) {
        if (actor.getRole() != EmployeeRole.COMPANY_ADMIN) {
            throw new RuntimeException("Access Denied: Chỉ có COMPANY_ADMIN mới được thực hiện thao tác này.");
        }
    }

    // =================================================================
    // 1. CREATE DEPARTMENT
    // =================================================================
    @Transactional
    public Department createDepartmentFull(Employee creator, String name, Long managerId, List<Long> memberIds, Boolean isHr) {
        // 1. Kiểm tra quyền
        requireAdminRole(creator);
        Long companyId = creator.getCompanyId();

        // 2. Khởi tạo đối tượng
        Department dept = new Department();
        dept.setName(name);
        dept.setCompanyId(companyId);
        dept.setColor(generateRandomColor());
        handleHrFlag(dept, isHr != null && isHr, companyId);
        
        Department savedDept = saveDepartmentWithRetry(dept);

        // 3. Xử lý Manager
        if (managerId != null) {
            Employee newManager = employeeRepository.findById(managerId)
                    .orElseThrow(() -> new RuntimeException("Manager not found"));

            if (!newManager.getCompanyId().equals(companyId)) {
                throw new RuntimeException("LỖI BẢO MẬT: Nhân viên này không thuộc công ty của bạn!");
            }

            Optional<Department> oldManagedDeptOpt = departmentRepository.findByManagerId(managerId);
            if (oldManagedDeptOpt.isPresent()) {
                Department oldDept = oldManagedDeptOpt.get();
                if (!oldDept.getId().equals(savedDept.getId())) {
                    oldDept.setManager(null);
                    departmentRepository.saveAndFlush(oldDept);
                }
            }

            newManager.setDepartment(savedDept);
            if (newManager.getRole() != EmployeeRole.MANAGER) {
                newManager.setRole(EmployeeRole.MANAGER);
                sendProfileRefreshSocket(newManager.getId());
            }
            
            employeeRepository.save(newManager);
            syncEmployeeToCore(newManager);
            savedDept.setManager(newManager);
            
            sendNotification(newManager, "Manager Appointment", 
                "Congratulations! You have been appointed as the Manager of " + savedDept.getName());
        }

        // 4. Xử lý Members
        if (memberIds != null && !memberIds.isEmpty()) {
            List<Employee> members = employeeRepository.findAllById(memberIds);
            for (Employee emp : members) {
                if (!emp.getCompanyId().equals(companyId)) continue;
                if (managerId != null && emp.getId().equals(managerId)) continue;

                // Logic clear cache phòng cũ của nhân viên
                if (emp.getDepartment() != null) {
                    evictDepartmentMembersCache(emp.getDepartment().getId());
                }

                if (emp.getRole() == EmployeeRole.MANAGER) {
                    Optional<Department> oldDept = departmentRepository.findByManagerId(emp.getId());
                    if (oldDept.isPresent()) {
                        oldDept.get().setManager(null);
                        departmentRepository.save(oldDept.get());
                    }
                    emp.setRole(EmployeeRole.STAFF);
                    sendProfileRefreshSocket(emp.getId());
                    sendNotification(emp, "Position Change", 
                        "You have been transferred to " + savedDept.getName() + " with the role of Staff.");
                } else {
                    sendProfileRefreshSocket(emp.getId());
                    sendNotification(emp, "Personnel Transfer", 
                        "You have been added to department: " + savedDept.getName());
                }

                emp.setDepartment(savedDept);
                employeeRepository.save(emp);
                syncEmployeeToCore(emp);
            }
        }

        Department finalDept = departmentRepository.save(savedDept);

        // [FIX] Xóa cache thủ công
        evictCompanyStructureCache(companyId);
        evictDepartmentMembersCache(finalDept.getId());
//CHat ---------------------------------------------------
        try {
        DepartmentSyncEvent event = new DepartmentSyncEvent();
        event.setEvent(DepartmentSyncEvent.ACTION_CREATE);
        event.setDeptId(savedDept.getId());
        event.setDeptName(savedDept.getName());
        event.setManagerId(managerId);
        event.setCompanyId(creator.getCompanyId());
        event.setMemberIds(memberIds); // Gửi danh sách member ban đầu

        // Gọi Producer bắn sự kiện
        employeeProducer.sendDepartmentEvent(event);
    } catch (Exception e) {
        log.error("⚠️ Lỗi gửi sang Chat: {}", e.getMessage());
    }
    // ---------------------------------------------------
        return finalDept;
    }

    // =================================================================
    // 2. UPDATE DEPARTMENT
    // =================================================================
    @Transactional
    public Department updateDepartment(Employee updater, Long deptId, String name, Long managerId, Boolean isHr) {
        requireAdminRole(updater);

        Department currentDept = departmentRepository.findById(deptId)
                .orElseThrow(() -> new RuntimeException("Department not found"));

        if (!currentDept.getCompanyId().equals(updater.getCompanyId())) {
             throw new RuntimeException("Access Denied: Phòng ban này không thuộc công ty của bạn.");
        }

        currentDept.setName(name);
      
        if (isHr != null) {
             handleHrFlag(currentDept, isHr, updater.getCompanyId());
        }

        if (managerId != null) {
            boolean isDifferentManager = currentDept.getManager() == null || !currentDept.getManager().getId().equals(managerId);

            if (isDifferentManager) {
                // Manager cũ
                Employee oldManager = currentDept.getManager();
                if (oldManager != null) {
                    oldManager.setRole(EmployeeRole.STAFF);
                    employeeRepository.saveAndFlush(oldManager);
                    syncEmployeeToCore(oldManager);
                    sendProfileRefreshSocket(oldManager.getId());
                    sendNotification(oldManager, "Manager Role Ended", 
                        "You are no longer the Manager of " + currentDept.getName() + ". Current role: Staff.");
                }

                // Manager mới
                Employee newManager = employeeRepository.findById(managerId)
                        .orElseThrow(() -> new RuntimeException("Manager not found"));

                if (!newManager.getCompanyId().equals(currentDept.getCompanyId())) {
                    throw new RuntimeException("LỖI BẢO MẬT: Nhân viên được chọn không thuộc công ty này!");
                }

                Optional<Department> oldManagedDeptOpt = departmentRepository.findByManagerId(managerId);
                if (oldManagedDeptOpt.isPresent()) {
                    Department oldDept = oldManagedDeptOpt.get();
                    if (!oldDept.getId().equals(deptId)) {
                        oldDept.setManager(null);
                        departmentRepository.saveAndFlush(oldDept);
                    }
                }

                newManager.setDepartment(currentDept);
                if (newManager.getRole() != EmployeeRole.MANAGER) {
                    newManager.setRole(EmployeeRole.MANAGER);
                }
                
                employeeRepository.saveAndFlush(newManager);
                syncEmployeeToCore(newManager);
                sendProfileRefreshSocket(newManager.getId());
                currentDept.setManager(newManager);
                
                sendNotification(newManager, "Manager Appointment", 
                    "Congratulations! You have been appointed as the Manager of " + currentDept.getName());
            }
        } else {
            // Bãi nhiệm
            if (currentDept.getManager() != null) {
                Employee oldManager = currentDept.getManager();
                oldManager.setRole(EmployeeRole.STAFF);
                employeeRepository.saveAndFlush(oldManager);
                syncEmployeeToCore(oldManager);
                sendProfileRefreshSocket(oldManager.getId());
                currentDept.setManager(null);
                
                sendNotification(oldManager, "Manager Role Ended", 
                    "You are no longer the Manager of " + currentDept.getName() + ".");
            }
        }

        Department updated = departmentRepository.saveAndFlush(currentDept);

        // [FIX] Xóa cache thủ công
        evictCompanyStructureCache(updater.getCompanyId());
        evictDepartmentMembersCache(deptId);

        return updated;
    }
    
    // =================================================================
    // 3. DELETE DEPARTMENT
    // =================================================================
    @Transactional
    public void deleteDepartment(Employee deleter, Long deptId) {
        requireAdminRole(deleter);
       

        Department dept = departmentRepository.findById(deptId)
                .orElseThrow(() -> new RuntimeException("Department not found"));
        
        if (!dept.getCompanyId().equals(deleter.getCompanyId())) {
             throw new RuntimeException("Access Denied.");
        }
// [MỚI] Bắn sự kiện XÓA
             try {
                DepartmentSyncEvent event = new DepartmentSyncEvent();
                event.setEvent(DepartmentSyncEvent.ACTION_DELETE);
                event.setDeptId(deptId);
                event.setCompanyId(deleter.getCompanyId());
                employeeProducer.sendDepartmentEvent(event);
             } catch (Exception e) {
                log.error("⚠️ Lỗi gửi lệnh xóa sang Chat: {}", e.getMessage());
             }
        
    
        // --- [TỐI ƯU HIỆU NĂNG] Batch Update ---
        // 1. Gỡ Request (Dùng saveAll để Hibernate batch update)
        List<Request> requests = requestRepository.findByDepartmentIdOrderByCreatedAtDesc(deptId);
        if (!requests.isEmpty()) {
            for (Request req : requests) req.setDepartment(null);
            requestRepository.saveAll(requests);
        }

        // 2. Xử lý nhân viên
        List<Employee> employees = employeeRepository.findByDepartmentId(deptId);
        if (!employees.isEmpty()) {
            for (Employee emp : employees) {
                sendNotification(emp, "Department Dissolution", "Department " + dept.getName() + " has been dissolved.");
                emp.setDepartment(null);
                if (emp.getRole() == EmployeeRole.MANAGER) {
                    emp.setRole(EmployeeRole.STAFF);
                    syncEmployeeToCore(emp);
                }
                sendProfileRefreshSocket(emp.getId());
            }
            employeeRepository.saveAll(employees);
        }
        // chat- ---------------------------------------------------
        try {
            DepartmentSyncEvent event = new DepartmentSyncEvent();
            event.setEvent(DepartmentSyncEvent.ACTION_DELETE);
            event.setDeptId(deptId);
            event.setCompanyId(dept.getCompanyId());
            employeeProducer.sendDepartmentEvent(event);

            // Gỡ nhân viên ra trước khi xóa để tránh lỗi DB
            employeeRepository.unlinkEmployeesFromDepartment(deptId);
        } catch (Exception e) { e.printStackTrace(); }
        // [HẾT ĐOẠN THÊM]
        
        // 3. Xóa phòng ban
        departmentRepository.delete(dept);

        // [FIX] Xóa cache thủ công
        evictCompanyStructureCache(deleter.getCompanyId());
        evictDepartmentMembersCache(deptId);
    }
    
    // =================================================================
    // 4. HELPER METHODS & GETTERS
    // =================================================================
    private void sendProfileRefreshSocket(Long userId) {
        try {
            String dest = "/topic/user/" + userId + "/profile";
            messagingTemplate.convertAndSend(dest, "REFRESH_PROFILE");
            log.info("--> WebSocket: Đã gửi lệnh REFRESH_PROFILE tới user {}", userId);
        } catch (Exception e) {
            log.error("Lỗi gửi socket profile: {}", e.getMessage());
        }
    }

    private void handleHrFlag(Department dept, boolean isHr, Long companyId) {
        if (isHr) {
            Optional<Department> currentHr = departmentRepository.findByCompanyIdAndIsHrTrue(companyId);
            if (currentHr.isPresent() && !currentHr.get().getId().equals(dept.getId())) {
                Department oldHr = currentHr.get();
                oldHr.setIsHr(false);
                departmentRepository.save(oldHr);
            }
            dept.setIsHr(true);
        } else {
            dept.setIsHr(false);
        }
    }

    private void sendNotification(Employee receiver, String title, String body) {
        try {
            NotificationEvent event = new NotificationEvent(
                receiver.getId(), title, body, "SYSTEM", null
            );
            employeeProducer.sendNotification(event);
        } catch (Exception e) {
            log.error("Lỗi gửi thông báo cho user {}: {}", receiver.getId(), e.getMessage());
        }
    }

    private void syncEmployeeToCore(Employee emp) {
        try {
            String deptName = (emp.getDepartment() != null) ? emp.getDepartment().getName() : "N/A";
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                emp.getId(), emp.getEmail(), emp.getFullName(), emp.getPhone(),
                emp.getDateOfBirth(), emp.getCompanyId(), emp.getRole().name(),
                emp.getStatus().name(), null, deptName,
                emp.getDepartment() != null ? emp.getDepartment().getId() : null //task
            );
            employeeProducer.sendEmployeeUpdatedEvent(event);
        } catch (Exception e) {
            log.error("Sync Error: {}", e.getMessage());
        }
    }

    private String generateRandomColor() {
        Random random = new Random();
        int nextInt = random.nextInt(0xffffff + 1);
        return String.format("#%06x", nextInt);
    }
    
    private Department saveDepartmentWithRetry(Department department) {
        int maxRetries = 3; 
        for (int i = 0; i < maxRetries; i++) {
            try {
                department.setDepartmentCode(generateRandomDeptCode());
                return departmentRepository.save(department);
            } catch (DataIntegrityViolationException e) {
                if (i == maxRetries - 1) throw new RuntimeException("System busy.");
            }
        }
        return null;
    }

    private String generateRandomDeptCode() {
        int randomNum = (int) (Math.random() * 10000); 
        return String.format("DEP%04d", randomNum);
    }

    @Cacheable(value = "departments_metadata", key = "#requester.companyId")
    public List<Department> getDepartmentsMetadata(Employee requester) {
        log.info("--> [DB HIT] Fetching Departments Metadata for Company: {}", requester.getCompanyId());
        return departmentRepository.findByCompanyId(requester.getCompanyId());
    }

    @Cacheable(value = "departments_stats", key = "#requester.companyId")
    public Map<String, Long> getDepartmentStats(Employee requester) {
        log.info("--> [DB HIT] Fetching Departments Stats for Company: {}", requester.getCompanyId());
        List<Object[]> results = departmentRepository.countMembersByCompany(requester.getCompanyId());
        
        return results.stream()
            .collect(Collectors.toMap(
                row -> String.valueOf(row[0]),
                row -> (Long) row[1]
            ));
    }

    private void populateMemberCounts(List<Department> departments, Employee requester) {
        if (departments == null || departments.isEmpty()) return;
        Map<String, Long> stats = self.getDepartmentStats(requester);
        for (Department dept : departments) {
            long count = stats.getOrDefault(String.valueOf(dept.getId()), 0L);
            dept.setMemberCount(count);
        }
    }

    public List<Department> getAllDepartments(Employee requester) {
        List<Department> departments = self.getDepartmentsMetadata(requester);
        populateMemberCounts(departments, requester);
        return departments;
    }

    @Transactional(readOnly = true)
    public List<Department> searchDepartments(Long requesterId, String keyword) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        List<Department> results = departmentRepository.searchDepartments(requester.getCompanyId(), keyword);
        populateMemberCounts(results, requester);
        return results;
    }

    public Department getHrDepartment(Employee requester) {
        Department hrDept = departmentRepository.findByCompanyIdAndIsHrTrue(requester.getCompanyId())
                .orElseThrow(() -> new RuntimeException("Chưa thiết lập phòng HR cho công ty này."));
        populateMemberCounts(Collections.singletonList(hrDept), requester);
        return hrDept;
    }
}