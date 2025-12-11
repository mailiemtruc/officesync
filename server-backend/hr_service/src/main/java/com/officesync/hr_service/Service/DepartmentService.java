package com.officesync.hr_service.Service;

import java.util.List;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j // Ghi log để theo dõi nếu có trùng
public class DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;

    // 1. Tạo phòng ban mới (CÓ RETRY - AN TOÀN TUYỆT ĐỐI)
    public Department createDepartment(Department department, Long companyId) {
        // Gán thông tin cơ bản
        department.setCompanyId(companyId);

        // Gọi hàm lưu an toàn với cơ chế thử lại
        return saveDepartmentWithRetry(department);
    }

    // Hàm xử lý Retry thông minh
    private Department saveDepartmentWithRetry(Department department) {
        int maxRetries = 3; // Thử tối đa 3 lần
        for (int i = 0; i < maxRetries; i++) {
            try {
                // Sinh mã ngẫu nhiên: DEP + 4 số (Ví dụ: DEP0921)
                department.setDepartmentCode(generateRandomDeptCode());
                
                // Thử lưu xuống DB
                return departmentRepository.save(department);
                
            } catch (DataIntegrityViolationException e) {
                // Nếu trùng mã, DB báo lỗi -> Log lại và thử tiếp
                log.warn("Đụng độ mã phòng ban: {}. Retry lần {}...", department.getDepartmentCode(), i + 1);
                
                if (i == maxRetries - 1) {
                    throw new RuntimeException("Hệ thống bận, không thể tạo phòng ban lúc này. Vui lòng thử lại.");
                }
            }
        }
        return null;
    }

    // Hàm sinh mã ngẫu nhiên
    private String generateRandomDeptCode() {
        int randomNum = (int) (Math.random() * 10000); // 0 -> 9999
        return String.format("DEP%04d", randomNum);
    }

    // 2. Bổ nhiệm Quản lý (Giữ nguyên logic cũ vì không sinh mã)
    @Transactional
    public Department assignManager(Long departmentId, Long employeeId) {
        Department department = departmentRepository.findById(departmentId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy phòng ban"));

        Employee newManager = employeeRepository.findById(employeeId)
                .orElseThrow(() -> new RuntimeException("Không tìm thấy nhân viên"));

        // Đảm bảo nhân viên thuộc về phòng ban đó
        if (newManager.getDepartment() == null || !newManager.getDepartment().getId().equals(departmentId)) {
            newManager.setDepartment(department);
        }

        // Thăng chức lên MANAGER
        if (newManager.getRole() == EmployeeRole.STAFF) {
            newManager.setRole(EmployeeRole.MANAGER);
            employeeRepository.save(newManager);
        }

        department.setManager(newManager);
        return departmentRepository.save(department);
    }

    // 3. Lấy danh sách
    public List<Department> getAllDepartments() {
        return departmentRepository.findAll();
    }
}