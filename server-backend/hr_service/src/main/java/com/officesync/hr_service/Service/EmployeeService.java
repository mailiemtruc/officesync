package com.officesync.hr_service.Service;
import java.util.Optional; // [QUAN TRỌNG] Class sinh ID

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.Config.SnowflakeIdGenerator;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.UserCreatedEvent;
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
        if (savedEmployee != null) {
            try {
                String passwordToSend = (password != null && !password.isEmpty()) ? password : "123456";

                EmployeeSyncEvent event = new EmployeeSyncEvent(
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
                log.info("--> Đã gửi yêu cầu tạo User sang Core (Email: {})", savedEmployee.getEmail());
                
            } catch (Exception e) {
                log.error("Lỗi gửi MQ sang Core: {}", e.getMessage());
            }
        }

        return savedEmployee;
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


   // 4. CẬP NHẬT THÔNG TIN (CÓ KIỂM TRA TRÙNG LẶP & ĐỒNG BỘ RABBITMQ)
    public Employee updateEmployee(Long id, String fullName, String phone, String dob) {
        // 1. Tìm nhân viên hiện tại
        Employee employee = employeeRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Employee not found"));

        // --- BƯỚC CHUẨN BỊ: Parse ngày sinh ---
        java.time.LocalDate newDob = null;
        if (dob != null && !dob.isEmpty()) {
            try {
                newDob = java.time.LocalDate.parse(dob);
            } catch (Exception e) {}
        }

        // --- BƯỚC KIỂM TRA: So sánh dữ liệu ---
        boolean isNameChanged = (fullName != null && !fullName.isEmpty() && !fullName.equals(employee.getFullName()));
        boolean isPhoneChanged = (phone != null && !phone.isEmpty() && !phone.equals(employee.getPhone()));
        boolean isDobChanged = false;
        if (newDob != null) {
            if (employee.getDateOfBirth() == null || !newDob.equals(employee.getDateOfBirth())) {
                isDobChanged = true;
            }
        }

        // Chặn Spam nếu không có gì thay đổi
        if (!isNameChanged && !isPhoneChanged && !isDobChanged) {
            throw new RuntimeException("No changes detected.");
        }

        // --- TIẾN HÀNH UPDATE ---
        if (isPhoneChanged) {
            if (employeeRepository.existsByPhone(phone)) {
                throw new RuntimeException("Phone number " + phone + " already exists!");
            }
            employee.setPhone(phone);
        }
        if (isNameChanged) {
            employee.setFullName(fullName);
        }
        if (isDobChanged) {
            employee.setDateOfBirth(newDob);
        }

        // 2. LƯU VÀO DB (HR SERVICE)
        Employee updatedEmployee = employeeRepository.save(employee);

        // 3. [MỚI] GỬI ĐỒNG BỘ SANG CORE SERVICE (RABBITMQ)
        try {
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                updatedEmployee.getEmail(),
                updatedEmployee.getFullName(),
                updatedEmployee.getPhone(),
                updatedEmployee.getDateOfBirth(),
                updatedEmployee.getCompanyId(),
                updatedEmployee.getRole().name(),
                updatedEmployee.getStatus().name(),
                null // Password: gửi null vì đây là update profile, không đổi pass
            );

            employeeProducer.sendEmployeeUpdatedEvent(event);
            
        } catch (Exception e) {
            // Chỉ log lỗi, không rollback transaction vì DB HR đã lưu thành công rồi.
            // Có thể thêm logic lưu vào bảng "failed_events" để retry sau.
            log.error("Lỗi khi gửi sự kiện update sang Core: {}", e.getMessage());
        }

        return updatedEmployee;
    }
}