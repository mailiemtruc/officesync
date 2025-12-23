package com.officesync.hr_service.Repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.Employee;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    // Tìm nhân viên theo mã code
    Optional<Employee> findByEmployeeCode(String employeeCode);
    
    Optional<Employee> findByEmail(String email);
    // [MỚI] Thêm 2 hàm này để kiểm tra trùng lặp nhanh
    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);
    // Lấy danh sách nhân viên theo phòng ban
    List<Employee> findByDepartmentId(Long departmentId);
 
   // [MỚI] Thêm hàm này để lấy danh sách nhân viên theo công ty
    List<Employee> findByCompanyId(Long companyId);
}