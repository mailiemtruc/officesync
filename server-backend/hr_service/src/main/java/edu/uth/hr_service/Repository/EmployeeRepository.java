package edu.uth.hr_service.Repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import edu.uth.hr_service.Model.Employee;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    // Tìm nhân viên theo mã code
    Optional<Employee> findByEmployeeCode(String employeeCode);
    
    // Check trùng mã code (dùng cho logic sinh mã)
    boolean existsByEmployeeCode(String employeeCode);

    // Lấy danh sách nhân viên theo phòng ban
    List<Employee> findByDepartmentId(Long departmentId);

    // Tìm quản lý của phòng ban (Logic: departmentId + Role MANAGER)
    // Optional<Employee> findByDepartmentIdAndRole(Long departmentId, EmployeeRole role);
}