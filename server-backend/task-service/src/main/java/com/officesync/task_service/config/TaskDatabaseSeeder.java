// com.officesync.task_service.config.TaskDatabaseSeeder.java
package com.officesync.task_service.config;

import java.util.List;
import java.util.Map;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;

import com.officesync.task_service.model.TaskUser;
import com.officesync.task_service.model.TaskDepartment;
import com.officesync.task_service.repository.TaskDepartmentRepository;
import com.officesync.task_service.repository.TaskUserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Component
@RequiredArgsConstructor
@Slf4j
public class TaskDatabaseSeeder implements CommandLineRunner {

    private final TaskDepartmentRepository deptRepo;
    private final TaskUserRepository userRepo;

    private final String HR_SERVICE_URL = "http://localhost:8081/api"; 

    @Override
    public void run(String... args) {
        // Thực hiện đồng bộ toàn bộ khi khởi chạy để làm đầy database
        log.info("--> [Seeder] Bắt đầu đồng bộ toàn bộ dữ liệu từ HR Service...");
        syncAllFromHr();
    }

    private void syncAllFromHr() {
        RestTemplate restTemplate = new RestTemplate();
        
        // SỬ DỤNG ID 5 (Admin) để HR Service cho phép lấy TOÀN BỘ danh sách
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-User-Id", "5"); 
        HttpEntity<String> entity = new HttpEntity<>(headers);

        try {
            // 1. Đồng bộ Departments trước
            ResponseEntity<List> deptResp = restTemplate.exchange(
                HR_SERVICE_URL + "/departments", HttpMethod.GET, entity, List.class
            );
            if (deptResp.getBody() != null) {
                List<Map<String, Object>> depts = deptResp.getBody();
                for (Map<String, Object> d : depts) {
                    TaskDepartment td = new TaskDepartment();
                    td.setId(((Number) d.get("id")).longValue());
                    td.setName((String) d.get("name"));
                    td.setCompanyId(((Number) d.get("companyId")).longValue());
                    td.setDepartmentCode((String) d.get("departmentCode"));
                    
                    // SỬA TẠI ĐÂY: Xử lý cả manager object lồng nhau
                    if (d.get("manager") != null && d.get("manager") instanceof Map) {
                        Map<String, Object> m = (Map<String, Object>) d.get("manager");
                        td.setManagerId(((Number) m.get("id")).longValue());
                    } else if (d.get("managerId") != null) {
                        td.setManagerId(((Number) d.get("managerId")).longValue());
                    }
                    
                    deptRepo.save(td);
                }
                log.info("--> [Seeder] Đã đồng bộ {} phòng ban.", depts.size());
            }

            // 2. Đồng bộ TOÀN BỘ Employees (Admin, Manager, Staff)
            ResponseEntity<List> empResp = restTemplate.exchange(
                HR_SERVICE_URL + "/employees", HttpMethod.GET, entity, List.class
            );
            
            if (empResp.getBody() != null) {
                List<Map<String, Object>> emps = empResp.getBody();
                for (Map<String, Object> e : emps) {
                    TaskUser tu = new TaskUser();
                    tu.setId(((Number) e.get("id")).longValue());
                    tu.setFullName((String) e.get("fullName"));
                    tu.setEmail((String) e.get("email"));
                    tu.setCompanyId(((Number) e.get("companyId")).longValue());
                    tu.setRole((String) e.get("role"));
                    tu.setStatus((String) e.get("status"));
                    
                    if (e.get("department") != null) {
                        Map<String, Object> dMap = (Map<String, Object>) e.get("department");
                        tu.setDepartmentId(((Number) dMap.get("id")).longValue());
                    }
                    userRepo.save(tu);
                }
                log.info("--> [Seeder] Đã đồng bộ thành công {} nhân viên (tất cả các vai trò).", emps.size());
            }

        } catch (Exception e) {
            log.error("--> [Seeder] Lỗi đồng bộ dữ liệu: {}. Kiểm tra xem HR Service có đang chạy không?", e.getMessage());
        }
    }
}