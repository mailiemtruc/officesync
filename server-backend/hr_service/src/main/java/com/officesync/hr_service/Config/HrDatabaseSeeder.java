package com.officesync.hr_service.Config;

import java.time.LocalDateTime;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.officesync.hr_service.Model.Department;
import com.officesync.hr_service.Repository.DepartmentRepository;

@Configuration
public class HrDatabaseSeeder {

    @Bean
    CommandLineRunner initHrData(DepartmentRepository departmentRepository) {
        return args -> {
            // Kiểm tra nếu chưa có phòng ban nào thì mới tạo
            if (departmentRepository.count() == 0) {
                Long fptCompanyId = 2L; // Giả định ID công ty của Admin là 1

                createDepartment(departmentRepository, "IT Department", "DEP001", fptCompanyId);
                createDepartment(departmentRepository, "Human Resources", "DEP002", fptCompanyId);
                createDepartment(departmentRepository, "Sales & Marketing", "DEP003", fptCompanyId);
                
                System.out.println("--> Đã tạo dữ liệu mẫu cho bảng Departments");
            }
        };
    }

    private void createDepartment(DepartmentRepository repo, String name, String code, Long companyId) {
        Department dept = new Department();
        dept.setName(name);
        dept.setDepartmentCode(code);
        dept.setCompanyId(companyId);
        dept.setCreatedAt(LocalDateTime.now());
        dept.setUpdatedAt(LocalDateTime.now());
        // Manager để null, sẽ bổ nhiệm sau qua API
        dept.setManager(null);
        
        repo.save(dept);
    }
}