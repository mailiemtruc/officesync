package com.officesync.hr_service.Service;
import org.springframework.dao.DataIntegrityViolationException; // [QUAN TRỌNG] Class sinh ID
import org.springframework.stereotype.Service;

import com.officesync.hr_service.Config.SnowflakeIdGenerator;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.DTO.UserCreatedEvent;
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Model.EmployeeStatus;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.Repository.DepartmentRepository; // Import DTO mới
import com.officesync.hr_service.Repository.EmployeeRepository; // Import Producer mới

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
        // 1. Gán Company ID
        newEmployee.setCompanyId(companyId);
        
        // 2. Default values
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);

        // 3. SINH SNOWFLAKE ID (Lưu cục bộ)
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

        // 5. Lưu vào DB của HR Service (KHÔNG LƯU PASSWORD VÌ MODEL KHÔNG CÓ TRƯỜNG ĐÓ)
        Employee savedEmployee = saveEmployeeWithRetry(newEmployee);

        // 6. GỬI MQ SANG CORE (KÈM MẬT KHẨU NHẬN ĐƯỢC TỪ APP)
        if (savedEmployee != null) {
            try {
                // Sử dụng mật khẩu được truyền vào từ App, nếu null thì mới dùng mặc định
                String passwordToSend = (password != null && !password.isEmpty()) ? password : "123456";

                EmployeeSyncEvent event = new EmployeeSyncEvent(
                    savedEmployee.getEmail(),
                    savedEmployee.getFullName(),
                    savedEmployee.getPhone(),
                    savedEmployee.getDateOfBirth(),
                    savedEmployee.getCompanyId(),
                    savedEmployee.getRole().name(),
                    savedEmployee.getStatus().name(),
                    passwordToSend // [QUAN TRỌNG] Gửi mật khẩu thật sang Core
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
    public void createEmployeeFromEvent(UserCreatedEvent event) {
        log.info("Bắt đầu đồng bộ User ID: {} từ Core Service...", event.getId());

        if (employeeRepository.existsById(event.getId())) {
            log.warn("Nhân viên ID {} đã tồn tại. Bỏ qua tạo mới.", event.getId());
            return;
        }

        Employee newEmployee = new Employee();
        // Gán ID từ Core Service
        newEmployee.setId(event.getId()); 
        newEmployee.setCompanyId(event.getCompanyId());
        newEmployee.setFullName(event.getFullName());
        newEmployee.setEmail(event.getEmail());
        newEmployee.setDateOfBirth(event.getDateOfBirth());
        newEmployee.setPhone(event.getMobileNumber());
        
        // Map Role
        try {
            newEmployee.setRole(EmployeeRole.valueOf(event.getRole()));
        } catch (Exception e) {
            newEmployee.setRole(EmployeeRole.STAFF);
        }

        // Map Status
        try {
            newEmployee.setStatus(EmployeeStatus.valueOf(event.getStatus()));
        } catch (Exception e) {
            newEmployee.setStatus(EmployeeStatus.ACTIVE);
        }

        // Lưu
        Employee saved = saveEmployeeWithRetry(newEmployee);
        if (saved != null) {
            log.info("Đã tạo thành công nhân viên từ Event: {}", saved.getFullName());
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
}