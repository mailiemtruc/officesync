package com.officesync.hr_service.Config;

import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Producer.EmployeeProducer;
import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.Repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.*;
import org.springframework.stereotype.Component;

@Aspect
@Component
@RequiredArgsConstructor
@Slf4j
public class SyncAspect {

    private final EmployeeProducer employeeProducer;
    private final EmployeeRepository employeeRepository;

    // 1. Bắt mọi hành động save() - Để gửi ID khủng lúc mới tạo
    @AfterReturning(pointcut = "execution(* com.officesync.hr_service.Repository.EmployeeRepository.save(..))", returning = "result")
    public void afterRepoSave(Object result) {
        if (result instanceof Employee) {
            broadcastToTask((Employee) result, "SAVE");
        }
    }

    // 2. Bắt lệnh XÓA - Để Task xóa ID khủng ngay khi HR bắt đầu Swap
    @After("execution(* com.officesync.hr_service.Repository.EmployeeRepository.delete*(..))")
    public void afterRepoDelete(JoinPoint joinPoint) {
        Object[] args = joinPoint.getArgs();
        if (args.length > 0 && args[0] instanceof Long) {
            employeeProducer.sendEmployeeDeletedEvent((Long) args[0]);
            log.info("🗑️ [AOP Sync] Báo Task Service xóa ID cũ: {}", args[0]);
        }
    }

    // 3. [SỬA LỖI QUAN TRỌNG] Đảm bảo gửi ID thật ngay sau khi Swap
    // Chúng ta nhắm vào kết thúc của hàm tạo hoặc đồng bộ trong Service
    @AfterReturning(pointcut = "execution(* com.officesync.hr_service.Service.EmployeeService.*(..))", returning = "result")
    public void afterServiceMethodReturn(Object result) {
        // Nếu hàm trả về Employee (đã swap ID xong), gửi ngay bản đó sang Task
        if (result instanceof Employee) {
            broadcastToTask((Employee) result, "SERVICE_REAL_ID");
        } 
        // Nếu trả về List (như sau khi sync all), gửi cả list
        else if (result instanceof java.util.List) {
            for (Object item : (java.util.List<?>) result) {
                if (item instanceof Employee) broadcastToTask((Employee) item, "SERVICE_LIST");
            }
        }
    }

    private void broadcastToTask(Employee emp, String source) {
        // Chỉ gửi nếu ID là ID thật (nhỏ hơn 1 tỷ) hoặc là lệnh lưu ban đầu
        String deptName = (emp.getDepartment() != null) ? emp.getDepartment().getName() : "N/A";
        Long deptId = (emp.getDepartment() != null) ? emp.getDepartment().getId() : null;

        EmployeeSyncEvent event = new EmployeeSyncEvent(
            emp.getId(), emp.getEmail(), emp.getFullName(), emp.getPhone(),
            emp.getDateOfBirth(), emp.getCompanyId(), emp.getRole().name(),
            emp.getStatus().name(), null, deptName, deptId
        );

        employeeProducer.sendEmployeeCreatedEventDirect(event);
        log.info("🚀 [AOP Sync] [{}] Gửi User: {} (ID: {})", source, emp.getFullName(), emp.getId());
    }
}