package edu.uth.hr_service.Service;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import edu.uth.hr_service.Model.Department;
import edu.uth.hr_service.Model.Employee;
import edu.uth.hr_service.Model.EmployeeRole;
import edu.uth.hr_service.Model.EmployeeStatus;
import edu.uth.hr_service.Repository.DepartmentRepository;
import edu.uth.hr_service.Repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j // Lombok annotation để ghi log
public class EmployeeService {

    private final EmployeeRepository employeeRepository;
    private final DepartmentRepository departmentRepository;

    public Employee createEmployee(Employee newEmployee, Long companyId, Long departmentId) {
      
        newEmployee.setCompanyId(companyId);
        
        if (newEmployee.getRole() == null) newEmployee.setRole(EmployeeRole.STAFF);
        if (newEmployee.getStatus() == null) newEmployee.setStatus(EmployeeStatus.ACTIVE);

        if (departmentId != null) {
            Department dept = departmentRepository.findById(departmentId)
                    .orElseThrow(() -> new RuntimeException("Phòng ban không tồn tại với ID: " + departmentId));
            newEmployee.setDepartment(dept);
        }

        // 2. Gọi hàm lưu an toàn
        return saveEmployeeWithRetry(newEmployee);
    }

    // Hàm riêng để xử lý Retry
    private Employee saveEmployeeWithRetry(Employee employee) {
        int maxRetries = 3; // Thử tối đa 3 lần (quá đủ cho xác suất 1 phần triệu)
        
        for (int i = 0; i < maxRetries; i++) {
            try {
                // Sinh mã mới mỗi lần thử
                employee.setEmployeeCode(generateRandomCode());
                
                // Cố gắng lưu xuống DB
                return employeeRepository.save(employee);
                
            } catch (DataIntegrityViolationException e) {
                // Đây là nơi bắt lỗi trùng mã từ Database bắn lên
                log.warn("Đụng độ mã nhân viên: {}. Đang thử lại lần {}...", employee.getEmployeeCode(), i + 1);
                
                // Nếu đã thử đến lần cuối mà vẫn lỗi thì mới bung Exception ra ngoài
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Hệ thống đang bận, không thể sinh mã nhân viên. Vui lòng thử lại sau.");
                }
                // Nếu chưa hết lượt, vòng lặp for sẽ chạy tiếp và sinh mã mới
            }
        }
        return null; // Không bao giờ chạy đến đây
    }

    private String generateRandomCode() {
        int randomNum = (int) (Math.random() * 1000000);
        return String.format("NV%06d", randomNum);
    }
}