package com.officesync.hr_service.Service;

import com.officesync.hr_service.DTO.EmployeeSyncEvent;
import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Producer.EmployeeProducer;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class EmployeeSyncListener {

    private final EmployeeProducer employeeProducer;

    // Hàm này sẽ tự động chạy SAU KHI Transaction lưu nhân viên thành công
    // Giúp đồng bộ sang Task Service bằng hàm Direct mới mà không cần sửa EmployeeService cũ
    public void syncNewEmployeeToTask(Employee emp) {
        String deptName = (emp.getDepartment() != null) ? emp.getDepartment().getName() : "N/A";
        EmployeeSyncEvent event = new EmployeeSyncEvent(
            emp.getId(), emp.getEmail(), emp.getFullName(), emp.getPhone(),
            emp.getDateOfBirth(), emp.getCompanyId(), emp.getRole().name(),
            emp.getStatus().name(), null, deptName,
            emp.getDepartment() != null ? emp.getDepartment().getId() : null
        );
        employeeProducer.sendEmployeeCreatedEventDirect(event);
    }
}