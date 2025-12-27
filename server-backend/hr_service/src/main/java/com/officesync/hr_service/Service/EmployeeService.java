package com.officesync.hr_service.Service;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional; // [QUAN TRỌNG] Class sinh ID

import org.springframework.dao.DataIntegrityViolationException;
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
import com.officesync.hr_service.Producer.EmployeeProducer; // Import DTO mới
import com.officesync.hr_service.Repository.DepartmentRepository; // Import Producer mới
import com.officesync.hr_service.Repository.EmployeeRepository;

import lombok.RequiredArgsConstructor; // Import DTO mới
import lombok.extern.slf4j.Slf4j; // Import Producer mới
@Service
@RequiredArgsConstructor
@Slf4j
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;

   private final SnowflakeIdGenerator idGenerator; // [QUAN TRỌNG] Inject bộ sinh ID
   private final EmployeeProducer employeeProducer;

  // =================================================================
    // 1. TẠO NHÂN VIÊN TỪ API -> GỬI SANG CORE
    // =================================================================
    public Employee createEmployee(Employee newEmployee, Long companyId, Long departmentId, String password) {
        
     
        if (employeeRepository.existsByEmail(newEmployee.getEmail())) {
       
  
            throw new RuntimeException("Email " + newEmployee.getEmail() + " already exists in the system!");
        }
        
        // 2. Check Phone
        if (employeeRepository.existsByPhone(newEmployee.getPhone())) {
            
            throw new RuntimeException("Phone number " + newEmployee.getPhone() + " already exists in the system!");
        }



        // 1. Gán Company ID
        newEmployee.setCompanyId(companyId);
        
        // 2. Default values
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);

        // 3. SINH SNOWFLAKE ID
        if (newEmployee.getId() == null) {
            long safeId = idGenerator.nextId();
            newEmployee.setId(safeId);
        }

        // 4. Gán phòng ban
        if (departmentId != null) {
            Department dept = departmentRepository.findById(departmentId)
                    .orElseThrow(() -> new RuntimeException("Phòng ban không tồn tại"));
            newEmployee.setDepartment(dept);
        }

        // 5. Lưu vào DB của HR Service
        Employee savedEmployee = saveEmployeeWithRetry(newEmployee);

        // 6. GỬI MQ SANG CORE
       // [SỬA ĐỔI QUAN TRỌNG TẠI ĐÂY]
        if (savedEmployee != null) {
            try {
                String passwordToSend = (password != null && !password.isEmpty()) ? password : "123456";

                EmployeeSyncEvent event = new EmployeeSyncEvent(
                    null, // [QUAN TRỌNG] Gửi NULL để Core tự sinh ID mới
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
                log.info("--> Đã gửi yêu cầu tạo User sang Core (Email: {}). ID gửi đi là NULL", savedEmployee.getEmail());
                
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

    // [MỚI] Hàm lấy danh sách nhân viên
    public java.util.List<Employee> getAllEmployeesByRequester(Long requesterId) {
        // 1. Tìm thông tin người đang gửi yêu cầu
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 2. Lấy Company ID của người đó
        Long companyId = requester.getCompanyId();

        // 3. Trả về tất cả nhân viên thuộc công ty đó (Hàm findByCompanyId bạn đã có trong Repo)
        return employeeRepository.findByCompanyId(companyId);
    }


   // =================================================================
    // [ĐÃ SỬA & TỐI ƯU] HÀM UPDATE ALL-IN-ONE
    // =================================================================
    @Transactional
    public Employee updateEmployee(
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
        // 1. Tìm nhân viên
        Employee employee = employeeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // [QUAN TRỌNG] Lưu lại trạng thái CŨ để so sánh sau này
        EmployeeRole oldRole = employee.getRole();
        Department oldDepartment = employee.getDepartment();

        // 2. Cập nhật thông tin cơ bản (Giữ nguyên logic validate của bạn)
        if (fullName != null && !fullName.isEmpty()) employee.setFullName(fullName);

        if (email != null && !email.isEmpty()) {
            if (!email.equals(employee.getEmail()) && employeeRepository.existsByEmail(email)) {
                throw new RuntimeException("Email already exists");
            }
            employee.setEmail(email);
        }

        if (phone != null && !phone.isEmpty()) {
            if (!phone.equals(employee.getPhone()) && employeeRepository.existsByPhone(phone)) {
                throw new RuntimeException("Phone already exists");
            }
            employee.setPhone(phone);
        }

        if (dob != null && !dob.isEmpty()) {
            try { 
                employee.setDateOfBirth(LocalDate.parse(dob)); 
            } catch (Exception e) {
                throw new RuntimeException("Invalid Date format (yyyy-MM-dd required)."); 
            }
        }
        
        if (avatarUrl != null && !avatarUrl.equals(employee.getAvatarUrl())) {
            deleteOldAvatarFromStorage(employee.getAvatarUrl());
            employee.setAvatarUrl(avatarUrl);
        }

        if (statusStr != null && !statusStr.isEmpty()) {
            try { employee.setStatus(EmployeeStatus.valueOf(statusStr.toUpperCase())); } catch (Exception e) { }
        }

        // 3. Cập nhật Role mới
        if (roleStr != null && !roleStr.isEmpty()) {
            try { employee.setRole(EmployeeRole.valueOf(roleStr.toUpperCase())); } catch (Exception e) { }
        }

          // 4. Cập nhật Phòng ban mới [ĐÃ SỬA LOGIC TẠI ĐÂY]
        if (departmentId != null) {
            if (departmentId == 0) {
                employee.setDepartment(null);
            } else {
                // Nếu ID > 0 -> Tìm và gán phòng ban như bình thường
                Department dept = departmentRepository.findById(departmentId).orElse(null); 
                if (dept != null) {
                    employee.setDepartment(dept);
                }
            }
        }


        // =================================================================
        // [LOGIC MỚI BẮT ĐẦU] ĐỒNG BỘ MANAGER ID VÀO BẢNG DEPARTMENT
        // =================================================================
        
        EmployeeRole newRole = employee.getRole();
        Department newDepartment = employee.getDepartment();

        // A. Xử lý trường hợp bị HẠ CHỨC hoặc CHUYỂN PHÒNG (Gỡ quyền Manager cũ)
        // Điều kiện: Trước đây là MANAGER
        if (oldRole == EmployeeRole.MANAGER) {
            // Bị hạ chức xuống STAFF ??
            boolean isDemoted = !newRole.equals(EmployeeRole.MANAGER);
            // Hoặc bị chuyển sang phòng khác (hoặc bị đuổi khỏi phòng) ??
            boolean isTransferred = (oldDepartment != null && newDepartment != null && !oldDepartment.getId().equals(newDepartment.getId()));
            boolean isLeftDept = (oldDepartment != null && newDepartment == null);

            if (isDemoted || isTransferred || isLeftDept) {
                // Kiểm tra: Nếu nhân viên này đang đứng tên Manager ở phòng cũ -> Gỡ ra
                if (oldDepartment != null && oldDepartment.getManager() != null 
                        && oldDepartment.getManager().getId().equals(employee.getId())) {
                    
                    log.info("--> [Logic] Gỡ quyền Manager của User {} tại phòng {}", employee.getId(), oldDepartment.getName());
                    oldDepartment.setManager(null);
                    departmentRepository.save(oldDepartment); // Lưu cập nhật bảng Department
                }
            }
        }

        // B. Xử lý trường hợp THĂNG CHỨC (Set quyền Manager mới)
        // Điều kiện: Role mới là MANAGER và có phòng ban
        if (newRole == EmployeeRole.MANAGER && newDepartment != null) {
            // Kiểm tra xem phòng mới đã có Manager chưa?
            Employee currentManager = newDepartment.getManager();
            
            // Nếu chưa có ai HOẶC người đó không phải là mình -> Set mình làm Manager
            if (currentManager == null || !currentManager.getId().equals(employee.getId())) {
                log.info("--> [Logic] Thăng chức User {} làm Manager phòng {}", employee.getId(), newDepartment.getName());
                newDepartment.setManager(employee);
                departmentRepository.save(newDepartment); // Lưu cập nhật bảng Department
            }
        }
        // =================================================================
        // [LOGIC MỚI KẾT THÚC]
        // =================================================================

        // 5. Save Employee
        Employee savedEmployee = employeeRepository.save(employee);

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
                null // Update không gửi password
            );
            employeeProducer.sendEmployeeUpdatedEvent(event);
            log.info("--> [UPDATE] Đã đồng bộ User {} sang Core", savedEmployee.getEmail());
        } catch (Exception e) {
            log.error("Lỗi gửi RabbitMQ: {}", e.getMessage());
        }

        return savedEmployee;
    }

    // [ĐÃ SỬA] Hàm Xóa: Gọi đúng sự kiện DELETE thay vì UPDATE
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
        // 1. Logic nghiệp vụ: Xác thực người dùng
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 2. Logic nghiệp vụ: Chỉ search trong công ty của người đó
        return employeeRepository.searchEmployees(requester.getCompanyId(), keyword);
    }
}