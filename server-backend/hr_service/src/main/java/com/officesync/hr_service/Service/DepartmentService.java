package com.officesync.hr_service.Service;

import java.util.List;
import java.util.Optional;
import java.util.Random;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.Repository.DepartmentRepository;
import com.officesync.hr_service.Repository.EmployeeRepository;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class DepartmentService {

    private final DepartmentRepository departmentRepository;
    private final EmployeeRepository employeeRepository;
    private final EmployeeProducer employeeProducer;

    // [BẢO MẬT] Hàm check quyền dùng chung
    private void requireAdminRole(Employee actor) {
        if (actor.getRole() != EmployeeRole.COMPANY_ADMIN) {
            throw new RuntimeException("Access Denied: Chỉ có COMPANY_ADMIN mới được thực hiện thao tác này.");
        }
    }
// [MỚI] Hàm logic đảm bảo chỉ có 1 phòng HR trong công ty
    private void handleHrFlag(Department dept, boolean isHr, Long companyId) {
        if (isHr) {
            // Tìm xem cty đã có phòng HR nào chưa
            Optional<Department> currentHr = departmentRepository.findByCompanyIdAndIsHrTrue(companyId);
            
            if (currentHr.isPresent() && !currentHr.get().getId().equals(dept.getId())) {
                // Gỡ quyền HR của phòng cũ
                Department oldHr = currentHr.get();
                oldHr.setIsHr(false);
                departmentRepository.save(oldHr);
            }
            dept.setIsHr(true);
        } else {
            dept.setIsHr(false);
        }
    }
    @Transactional
    public Department createDepartmentFull(Employee creator, String name, String description, Long managerId, List<Long> memberIds,Boolean isHr) {
        // 1. Kiểm tra quyền
        requireAdminRole(creator);
        
        Long companyId = creator.getCompanyId();

        // 2. Khởi tạo đối tượng
        Department dept = new Department();
        dept.setName(name);
        dept.setDescription(description);
        dept.setCompanyId(companyId);
        dept.setColor(generateRandomColor());
       // [MỚI] Xử lý cờ HR
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
            }
            
            employeeRepository.save(newManager);
            syncEmployeeToCore(newManager);
            savedDept.setManager(newManager);
        }

        // 4. Xử lý Members
        if (memberIds != null && !memberIds.isEmpty()) {
            List<Employee> members = employeeRepository.findAllById(memberIds);
            for (Employee emp : members) {
                if (!emp.getCompanyId().equals(companyId)) continue;
                if (managerId != null && emp.getId().equals(managerId)) continue;

                if (emp.getRole() == EmployeeRole.MANAGER) {
                    Optional<Department> oldDept = departmentRepository.findByManagerId(emp.getId());
                    if (oldDept.isPresent()) {
                        oldDept.get().setManager(null);
                        departmentRepository.save(oldDept.get());
                    }
                    emp.setRole(EmployeeRole.STAFF);
                }

                emp.setDepartment(savedDept);
                employeeRepository.save(emp);
                syncEmployeeToCore(emp);
            }
        }

        return departmentRepository.save(savedDept);
    }

    @Transactional
    public Department updateDepartment(Employee updater, Long deptId, String name, String description, Long managerId,Boolean isHr) {
        // 1. Kiểm tra quyền
        requireAdminRole(updater);

        Department currentDept = departmentRepository.findById(deptId)
                .orElseThrow(() -> new RuntimeException("Department not found"));

        // Kiểm tra cùng công ty
        if (!currentDept.getCompanyId().equals(updater.getCompanyId())) {
             throw new RuntimeException("Access Denied: Phòng ban này không thuộc công ty của bạn.");
        }

        currentDept.setName(name);
        currentDept.setDescription(description);
        // [MỚI] Xử lý cờ HR
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
                    employeeRepository.save(oldManager);
                    syncEmployeeToCore(oldManager);
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
                
                employeeRepository.save(newManager);
                syncEmployeeToCore(newManager);
                
                currentDept.setManager(newManager);
            }
        } else {
            // Bãi nhiệm
            if (currentDept.getManager() != null) {
                Employee oldManager = currentDept.getManager();
                oldManager.setRole(EmployeeRole.STAFF);
                employeeRepository.save(oldManager);
                syncEmployeeToCore(oldManager);
                currentDept.setManager(null);
            }
        }

        return departmentRepository.save(currentDept);
    }

    @Transactional
    public void deleteDepartment(Employee deleter, Long deptId) {
        // 1. Kiểm tra quyền
        requireAdminRole(deleter);

        Department dept = departmentRepository.findById(deptId)
                .orElseThrow(() -> new RuntimeException("Department not found"));
        
        if (!dept.getCompanyId().equals(deleter.getCompanyId())) {
             throw new RuntimeException("Access Denied.");
        }

        List<Employee> employees = employeeRepository.findByDepartmentId(deptId);
        
        for (Employee emp : employees) {
            emp.setDepartment(null);
            if (emp.getRole() == EmployeeRole.MANAGER) {
                emp.setRole(EmployeeRole.STAFF);
                syncEmployeeToCore(emp);
            }
        }
        employeeRepository.saveAll(employees);
        departmentRepository.delete(dept);
    }

    // Các hàm phụ trợ giữ nguyên
    private void syncEmployeeToCore(Employee emp) {
        try {
            EmployeeSyncEvent event = new EmployeeSyncEvent(
                emp.getId(),
                emp.getEmail(),
                emp.getFullName(),
                emp.getPhone(),
                emp.getDateOfBirth(),
                emp.getCompanyId(),
                emp.getRole().name(),
                emp.getStatus().name(),
                null
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

  // [ĐÃ SỬA BẢO MẬT] Thay vì findAll(), ta lọc theo Company của người yêu cầu
    public List<Department> getAllDepartments(Long requesterId) {
        // 1. Xác thực người dùng
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        // 2. Chỉ trả về dữ liệu thuộc công ty của người đó
        return departmentRepository.findByCompanyId(requester.getCompanyId());
    }

    public List<Department> searchDepartments(Long requesterId, String keyword) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return departmentRepository.searchDepartments(requester.getCompanyId(), keyword);
    }

    // [MỚI] Lấy thông tin phòng HR của công ty
    public Department getHrDepartment(Long requesterId) {
        Employee requester = employeeRepository.findById(requesterId)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        // Tìm phòng ban có cờ isHr = true trong công ty
        return departmentRepository.findByCompanyIdAndIsHrTrue(requester.getCompanyId())
                .orElseThrow(() -> new RuntimeException("Chưa thiết lập phòng HR cho công ty này."));
    }
}