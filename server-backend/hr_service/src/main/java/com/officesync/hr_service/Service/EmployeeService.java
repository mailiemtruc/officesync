package com.officesync.hr_service.Service;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.dao.DataIntegrityViolationException; // [QUAN TRỌNG] Class sinh ID
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.Config.SnowflakeIdGenerator;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.UserCreatedEvent;
import com.officesync.hr_service.DTO.UserStatusChangedEvent;
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Model.EmployeeStatus;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.Repository.DepartmentRepository; // Import DTO mới
import com.officesync.hr_service.Repository.EmployeeRepository; // Import Producer mới

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j; // Import DTO mới
@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;

   private final SnowflakeIdGenerator idGenerator; // [QUAN TRỌNG] Inject bộ sinh ID
   private final EmployeeProducer employeeProducer;

  // [SỬA] Thay tham số Long companyId -> Employee creator
    public Employee createEmployee(Employee newEmployee, Employee creator, Long departmentId, String password) {
        
        // 1. KIỂM TRA QUYỀN HẠN (Permission Check)
        EmployeeRole creatorRole = creator.getRole();

        // TRƯỜNG HỢP 1: STAFF -> CHẶN NGAY
        if (creatorRole == EmployeeRole.STAFF) {
            throw new RuntimeException("Truy cập bị từ chối: Nhân viên không có quyền tạo người dùng mới.");
        }

        // TRƯỜNG HỢP 2: MANAGER -> GIỚI HẠN QUYỀN
        if (creatorRole == EmployeeRole.MANAGER) {
            // A. Manager CHỈ được tạo nhân viên là STAFF
            newEmployee.setRole(EmployeeRole.STAFF);

            // B. Manager CHỈ được thêm vào phòng ban của chính mình
            if (creator.getDepartment() != null) {
                // Ghi đè departmentId gửi lên bằng ID phòng của Manager
                departmentId = creator.getDepartment().getId(); 
            } else {
                throw new RuntimeException("Lỗi: Bạn là Manager nhưng chưa thuộc phòng ban nào, không thể tạo nhân viên.");
            }
        }
        
        // TRƯỜNG HỢP 3: COMPANY_ADMIN -> Cho phép tạo tùy ý (Giữ nguyên role/dept gửi lên)

        // =================================================================
        
        // 2. Check trùng lặp (Giữ nguyên)
        if (employeeRepository.existsByEmail(newEmployee.getEmail())) {
            throw new RuntimeException("Email " + newEmployee.getEmail() + " already exists!");
        }
        if (employeeRepository.existsByPhone(newEmployee.getPhone())) {
            throw new RuntimeException("Phone " + newEmployee.getPhone() + " already exists!");
        }

        // 3. Gán Company ID (Lấy từ người tạo)
        newEmployee.setCompanyId(creator.getCompanyId());
        
        // 4. Default values
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);

        // 5. Sinh ID (Giữ nguyên)
        if (newEmployee.getId() == null) {
            newEmployee.setId(idGenerator.nextId());
        }

        // 6. Gán phòng ban (Logic cũ nhưng biến departmentId đã được "sạch" hóa ở trên)
        if (departmentId != null) {
            Department dept = departmentRepository.findById(departmentId)
                    .orElseThrow(() -> new RuntimeException("Phòng ban không tồn tại"));
            newEmployee.setDepartment(dept);
        }

        // 7. Lưu & Gửi RabbitMQ (Giữ nguyên đoạn code cũ)
        Employee savedEmployee = saveEmployeeWithRetry(newEmployee);
        
        if (savedEmployee != null) {
            try {
                String passwordToSend = (password != null && !password.isEmpty()) ? password : "123456";

                EmployeeSyncEvent event = new EmployeeSyncEvent(
                    null, 
                    savedEmployee.getEmail(),
                    savedEmployee.getFullName(),
                    savedEmployee.getPhone(),
                    savedEmployee.getDateOfBirth(),
                    savedEmployee.getCompanyId(),
                    savedEmployee.getRole().name(),
                    savedEmployee.getStatus().name(),
                    passwordToSend 
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
                employeeRepository.save(emp);
                
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

        // Bước 1: Tìm nhân viên hiện tại trong HR bằng Email (đang giữ ID Snowflake tạm hoặc ID cũ)
        Optional<Employee> existingOpt = employeeRepository.findByEmail(event.getEmail());

        if (existingOpt.isPresent()) {
            Employee existingEmp = existingOpt.get();

            // Nếu ID đã khớp nhau rồi (Core ID == HR ID) -> Không cần làm gì
            if (existingEmp.getId().equals(event.getId())) {
                log.info("User đã được đồng bộ trước đó. Bỏ qua.");
                return;
            }

            // --- XỬ LÝ XUNG ĐỘT (ID SWAPPING) ---
            log.info("--> PHÁT HIỆN ID TẠM ({}). TIẾN HÀNH TRÁO ĐỔI SANG ID CORE ({})", existingEmp.getId(), event.getId());

            // 1. Backup dữ liệu HR-specific (Core không có những trường này)
            Department savedDept = existingEmp.getDepartment();
            String savedCode = existingEmp.getEmployeeCode();
            Long companyId = existingEmp.getCompanyId();

            // 2. Xóa bản ghi cũ (ID Snowflake)
            employeeRepository.delete(existingEmp);
            
            // [QUAN TRỌNG] Flush để DB xóa ngay lập tức
            // Nếu không flush, Hibernate có thể hoãn lệnh delete, gây lỗi "Duplicate Entry" khi save bản ghi mới
            employeeRepository.flush(); 

            // 3. Tạo bản ghi mới với ID chuẩn từ Core
            Employee newSyncEmp = new Employee();
            newSyncEmp.setId(event.getId()); // [QUAN TRỌNG] Dùng ID từ Core
            
            // Restore dữ liệu cũ (Dữ liệu đặc thù của HR)
            newSyncEmp.setDepartment(savedDept);
            newSyncEmp.setEmployeeCode(savedCode);
            newSyncEmp.setCompanyId(companyId);

            // Cập nhật thông tin mới nhất từ Event (để đảm bảo đồng nhất 2 bên)
            newSyncEmp.setFullName(event.getFullName());
            newSyncEmp.setEmail(event.getEmail());
            newSyncEmp.setPhone(event.getMobileNumber());
            newSyncEmp.setDateOfBirth(event.getDateOfBirth());

            // Xử lý Enum an toàn (Tránh lỗi nếu Core gửi string lạ)
            try { newSyncEmp.setRole(EmployeeRole.valueOf(event.getRole())); } 
            catch (Exception e) { newSyncEmp.setRole(EmployeeRole.STAFF); }

            try { newSyncEmp.setStatus(EmployeeStatus.valueOf(event.getStatus())); } 
            catch (Exception e) { newSyncEmp.setStatus(EmployeeStatus.ACTIVE); }

            // Lưu bản ghi mới
            employeeRepository.save(newSyncEmp);
            log.info("--> ĐỒNG BỘ THÀNH CÔNG. Nhân viên {} giờ có ID chuẩn: {}", event.getEmail(), event.getId());

        } else {
            // Trường hợp: User được tạo trực tiếp từ Core (Admin dashboard) -> Tạo mới hoàn toàn
            log.info("--> Không tìm thấy nhân viên cũ. Tạo mới hoàn toàn từ Core Event.");
            
            Employee newEmployee = new Employee();
            newEmployee.setId(event.getId()); 
            newEmployee.setCompanyId(event.getCompanyId());
            newEmployee.setFullName(event.getFullName());
            newEmployee.setEmail(event.getEmail());
            newEmployee.setDateOfBirth(event.getDateOfBirth());
            newEmployee.setPhone(event.getMobileNumber());
            
            try { newEmployee.setRole(EmployeeRole.valueOf(event.getRole())); } 
            catch (Exception e) { newEmployee.setRole(EmployeeRole.STAFF); } // Hoặc MANAGER tùy logic

            try { newEmployee.setStatus(EmployeeStatus.valueOf(event.getStatus())); } 
            catch (Exception e) { newEmployee.setStatus(EmployeeStatus.ACTIVE); }

            // Dùng hàm retry để tự động sinh mã nhân viên (NVxxxxxx)
            saveEmployeeWithRetry(newEmployee);
        }
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

 public List<Employee> getAllEmployeesByRequester(Long requesterId) {
        // 1. Xác định người gọi
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 2. PHÂN QUYỀN CHẶT CHẼ 3 CẤP
        EmployeeRole role = requester.getRole();

        // CẤP 1: ADMIN - Xem toàn bộ công ty
        if (role == EmployeeRole.COMPANY_ADMIN) {
            return employeeRepository.findByCompanyId(requester.getCompanyId());
        }

        // CẤP 2: MANAGER - Xem nhân viên phòng ban mình
        if (role == EmployeeRole.MANAGER) {
            if (requester.getDepartment() != null) {
                return employeeRepository.findByDepartmentId(requester.getDepartment().getId());
            } else {
                // Manager chưa có phòng -> Chỉ thấy chính mình (hoặc rỗng)
                return List.of(requester); 
            }
        }

        // CẤP 3: STAFF - Chỉ xem được chính mình (An toàn nhất)
        // (Hoặc nếu muốn Staff xem được đồng nghiệp cùng phòng thì dùng logic giống Manager)
        return List.of(requester); 
    }

   // [CẬP NHẬT] Thêm tham số 'Employee updater' vào đầu hàm
    @Transactional
    public Employee updateEmployee(
            Employee updater, // <--- Người thực hiện sửa
            Long id, 
            String fullName, 
            String phone, 
            String dob, 
            String avatarUrl, 
            String statusStr, 
            String roleStr, 
            Long departmentId,
            String email
    ) {
        // 1. Tìm nhân viên cần sửa (Target)
        Employee targetEmployee = employeeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // =========================================================
        // [BẢO MẬT] KIỂM TRA QUYỀN HẠN (Permission Check)
        // =========================================================
        
        // Nếu người sửa là STAFF -> Chặn luôn (Staff không được sửa hồ sơ người khác)
        // Lưu ý: Nếu muốn cho phép Staff tự sửa hồ sơ mình thì thêm điều kiện (updater.getId().equals(id))
        if (updater.getRole() == EmployeeRole.STAFF) {
             throw new RuntimeException("Truy cập bị từ chối: Nhân viên không có quyền chỉnh sửa.");
        }

        // Nếu người sửa là MANAGER
        if (updater.getRole() == EmployeeRole.MANAGER) {
            
            // A. Manager KHÔNG ĐƯỢC sửa người của phòng khác
            // Logic: Nếu Manager chưa có phòng, hoặc Target chưa có phòng, hoặc ID phòng khác nhau
            if (updater.getDepartment() == null || 
                targetEmployee.getDepartment() == null ||
                !updater.getDepartment().getId().equals(targetEmployee.getDepartment().getId())) {
                
                throw new RuntimeException("Truy cập bị từ chối: Bạn chỉ được chỉnh sửa nhân viên trong phòng ban của mình.");
            }

            // B. Manager KHÔNG ĐƯỢC đổi Role (Quyền)
            // Nếu có gửi role mới lên VÀ role mới khác role cũ -> Chặn
            if (roleStr != null && !roleStr.isEmpty() && !roleStr.equalsIgnoreCase(targetEmployee.getRole().name())) {
                throw new RuntimeException("Truy cập bị từ chối: Manager không có quyền thay đổi chức vụ (Role).");
            }

            // C. Manager KHÔNG ĐƯỢC đổi Phòng ban (Transfer)
            // Nếu có gửi ID phòng mới lên VÀ ID đó khác ID phòng hiện tại -> Chặn
            if (departmentId != null && !departmentId.equals(targetEmployee.getDepartment().getId())) {
                throw new RuntimeException("Truy cập bị từ chối: Manager không có quyền điều chuyển nhân sự sang phòng khác.");
            }
        }
        
        // =========================================================
        // [KẾT THÚC KIỂM TRA BẢO MẬT]
        // =========================================================

        // Lưu lại trạng thái cũ để xử lý logic đồng bộ Manager (cho Admin dùng)
        EmployeeRole oldRole = targetEmployee.getRole();
        Department oldDepartment = targetEmployee.getDepartment();

        // 2. Cập nhật thông tin cơ bản
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
            try { 
                targetEmployee.setDateOfBirth(LocalDate.parse(dob)); 
            } catch (Exception e) {
                throw new RuntimeException("Invalid Date format (yyyy-MM-dd required)."); 
            }
        }
        
        if (avatarUrl != null && !avatarUrl.equals(targetEmployee.getAvatarUrl())) {
            deleteOldAvatarFromStorage(targetEmployee.getAvatarUrl());
            targetEmployee.setAvatarUrl(avatarUrl);
        }

        if (statusStr != null && !statusStr.isEmpty()) {
            try { targetEmployee.setStatus(EmployeeStatus.valueOf(statusStr.toUpperCase())); } catch (Exception e) { }
        }

        // 3. Cập nhật Role mới (Chỉ Admin mới chạy được xuống đây nếu đổi role, Manager đã bị chặn ở trên)
        if (roleStr != null && !roleStr.isEmpty()) {
            try { targetEmployee.setRole(EmployeeRole.valueOf(roleStr.toUpperCase())); } catch (Exception e) { }
        }

        // 4. Cập nhật Phòng ban mới (Chỉ Admin mới chạy được xuống đây nếu đổi phòng)
        if (departmentId != null) {
            if (departmentId == 0) {
                targetEmployee.setDepartment(null);
            } else {
                Department dept = departmentRepository.findById(departmentId).orElse(null); 
                if (dept != null) {
                    targetEmployee.setDepartment(dept);
                }
            }
        }

        // =================================================================
        // [LOGIC ĐỒNG BỘ MANAGER ID VÀO BẢNG DEPARTMENT] (Giữ nguyên)
        // =================================================================
        
        EmployeeRole newRole = targetEmployee.getRole();
        Department newDepartment = targetEmployee.getDepartment();

        // A. Xử lý trường hợp bị HẠ CHỨC hoặc CHUYỂN PHÒNG
        if (oldRole == EmployeeRole.MANAGER) {
            boolean isDemoted = !newRole.equals(EmployeeRole.MANAGER);
            boolean isTransferred = (oldDepartment != null && newDepartment != null && !oldDepartment.getId().equals(newDepartment.getId()));
            boolean isLeftDept = (oldDepartment != null && newDepartment == null);

            if (isDemoted || isTransferred || isLeftDept) {
                if (oldDepartment != null && oldDepartment.getManager() != null 
                        && oldDepartment.getManager().getId().equals(targetEmployee.getId())) {
                    
                    log.info("--> [Logic] Gỡ quyền Manager cũ tại phòng {}", oldDepartment.getName());
                    oldDepartment.setManager(null);
                    departmentRepository.save(oldDepartment);
                }
            }
        }

        // B. Xử lý trường hợp THĂNG CHỨC
        if (newRole == EmployeeRole.MANAGER && newDepartment != null) {
            Employee currentManager = newDepartment.getManager();
            if (currentManager == null || !currentManager.getId().equals(targetEmployee.getId())) {
                log.info("--> [Logic] Thăng chức User {} làm Manager phòng {}", targetEmployee.getId(), newDepartment.getName());
                newDepartment.setManager(targetEmployee);
                departmentRepository.save(newDepartment);
            }
        }

        // 5. Save Employee
        Employee savedEmployee = employeeRepository.save(targetEmployee);

        // 6. Gửi RabbitMQ đồng bộ
        try {
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                savedEmployee.getId(),
                savedEmployee.getEmail(),
                savedEmployee.getFullName(),
                savedEmployee.getPhone(),
                savedEmployee.getDateOfBirth(),
                savedEmployee.getCompanyId(),
                savedEmployee.getRole().name(), 
                savedEmployee.getStatus().name(),
                null
            );
            employeeProducer.sendEmployeeUpdatedEvent(event);
        } catch (Exception e) {
            log.error("Lỗi gửi RabbitMQ: {}", e.getMessage());
        }

        return savedEmployee;
    }


    @Transactional
    public void deleteEmployee(Long id) {
        Employee employee = employeeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // 1. Gửi sự kiện yêu cầu XÓA user sang Core (User sẽ bị xóa khỏi bảng users)
        try {
            // Sử dụng hàm sendEmployeeDeletedEvent đã có trong Producer
            employeeProducer.sendEmployeeDeletedEvent(employee.getId()); 
            log.info("--> Đã gửi lệnh xóa User ID {} sang Core", employee.getId());
        } catch (Exception e) {
            log.error("Lỗi gửi event xóa: {}", e.getMessage());
        }

        // 2. Xóa khỏi DB của HR
        employeeRepository.delete(employee);
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
}