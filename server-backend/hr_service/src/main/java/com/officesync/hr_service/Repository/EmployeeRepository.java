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
    // Thêm vào trong interface EmployeeRepository
   List<Employee> findByCompanyIdAndRole(Long companyId, EmployeeRole role);
    Optional<Employee> findByEmail(String email);
    // [MỚI] Thêm 2 hàm này để kiểm tra trùng lặp nhanh
    boolean existsByEmail(String email);
    boolean existsByPhone(String phone);
    // Lấy danh sách nhân viên theo phòng ban
    List<Employee> findByDepartmentId(Long departmentId);
 
   // [MỚI] Thêm hàm này để lấy danh sách nhân viên theo công ty
    List<Employee> findByCompanyId(Long companyId);

    // Tìm theo Tên hoặc Mã nhân viên (không phân biệt hoa thường)
 List<Employee> findByFullNameContainingIgnoreCaseOrEmployeeCodeContainingIgnoreCase(String name, String code);
// Tìm kiếm: Bắt buộc phải có companyId để đảm bảo tính riêng tư
    @Query("SELECT e FROM Employee e WHERE e.companyId = :companyId " +
           "AND (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Employee> searchEmployees(@Param("companyId") Long companyId, @Param("keyword") String keyword);

    // [MỚI - CHUẨN DOANH NGHIỆP] Tìm kiếm để Chọn (Manager/Member)
    // 1. Cùng Company
    // 2. Trạng thái ACTIVE (nghỉ việc không hiện)
    // 3. Không phải COMPANY_ADMIN (Sếp tổng không làm trưởng phòng con)
    // 4. Khác requesterId (Không hiện chính mình)
    @Query("SELECT e FROM Employee e WHERE " +
           "e.companyId = :companyId " +
           "AND e.id <> :requesterId " + 
           "AND e.status = 'ACTIVE' " + 
           "AND e.role <> 'COMPANY_ADMIN' " + 
           "AND (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Employee> searchStaffForSelection(
        @Param("companyId") Long companyId, 
        @Param("requesterId") Long requesterId, 
        @Param("keyword") String keyword
    );

    // [MỚI] Search chỉ trong một phòng ban cụ thể
    @Query("SELECT e FROM Employee e WHERE e.department.id = :deptId " +
           "AND (LOWER(e.fullName) LIKE LOWER(CONCAT('%', :keyword, '%')) " +
           "OR LOWER(e.employeeCode) LIKE LOWER(CONCAT('%', :keyword, '%')))")
    List<Employee> searchEmployeesInDepartment(@Param("deptId") Long deptId, @Param("keyword") String keyword);
}