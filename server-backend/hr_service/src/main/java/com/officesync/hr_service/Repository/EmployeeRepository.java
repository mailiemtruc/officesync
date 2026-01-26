package com.officesync.hr_service.Repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.officesync.hr_service.Model.Employee;
import com.officesync.hr_service.Model.EmployeeRole;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long> {

   
    // Tìm nhân viên theo mã code
    Optional<Employee> findByEmployeeCode(String employeeCode);

    Optional<Employee> findByEmail(String email);

    // Kiểm tra tồn tại (Hiệu năng rất tốt vì count(*))
    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);


    // --- CÁC HÀM TRẢ VỀ LIST (CẦN TỐI ƯU JOIN FETCH) ---

   
    // Dùng JOIN FETCH để lấy luôn Department, tránh việc load 100 nhân viên thì bắn thêm 100 query lấy phòng ban
    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE e.companyId = :companyId")
    List<Employee> findByCompanyId(@Param("companyId") Long companyId);

    @Query("SELECT e.id FROM Employee e WHERE e.companyId = :companyId")
    List<Long> findIdsByCompanyId(@Param("companyId") Long companyId);

    @Query("SELECT e.id FROM Employee e WHERE e.department.id = :departmentId")
    List<Long> findIdsByDepartmentId(@Param("departmentId") Long departmentId);

    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE e.id IN :ids")
    List<Employee> findByIdInFetchDepartment(@Param("ids") List<Long> ids);
  
    // Mặc dù đã biết phòng ban, nhưng vẫn fetch để object Employee đầy đủ data nếu dùng ở nơi khác
    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE e.department.id = :departmentId")
    List<Employee> findByDepartmentId(@Param("departmentId") Long departmentId);

    //  Lấy theo role
    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE e.companyId = :companyId AND e.role = :role")
    List<Employee> findByCompanyIdAndRole(@Param("companyId") Long companyId, @Param("role") EmployeeRole role);



    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE e.companyId = :companyId " +
           "AND (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.department.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +           
           "OR LOWER(e.department.departmentCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")  
    List<Employee> searchEmployees(@Param("companyId") Long companyId, @Param("keyword") String keyword);

 
    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE " +
           "e.companyId = :companyId " +
           "AND e.id <> :requesterId " + 
           "AND e.status = 'ACTIVE' " + 
           "AND e.role <> 'COMPANY_ADMIN' " + 
           "AND (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.department.name) LIKE LOWER(CONCAT('%', :keyword, '%')) " +          
           "OR LOWER(e.department.departmentCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")  
    List<Employee> searchStaffForSelection(
        @Param("companyId") Long companyId, 
        @Param("requesterId") Long requesterId, 
        @Param("keyword") String keyword
    );

    // [TỐI ƯU] Search trong phòng ban cụ thể
    @Query("SELECT e FROM Employee e LEFT JOIN FETCH e.department WHERE e.department.id = :deptId " +
           "AND (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Employee> searchEmployeesInDepartment(@Param("deptId") Long deptId, @Param("keyword") String keyword);
    
    @Query("SELECT e.id FROM Employee e " +
           "LEFT JOIN e.department d " +
           "WHERE e.companyId = :companyId " +
           "AND (e.role = 'COMPANY_ADMIN' OR e.role = 'MANAGER' OR d.isHr = true)")
    List<Long> findApproverIdsByCompany(@Param("companyId") Long companyId);

    // [CHAT] Gỡ nhân viên khỏi phòng ban nhanh--------------------------------------------------
    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.data.jpa.repository.Query("UPDATE Employee e SET e.department = NULL WHERE e.department.id = :deptId")
    void unlinkEmployeesFromDepartment(@org.springframework.data.repository.query.Param("deptId") Long deptId);
}