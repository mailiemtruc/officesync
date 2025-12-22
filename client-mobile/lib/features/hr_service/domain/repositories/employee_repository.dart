import '../../data/models/employee_model.dart'; // Import Model
import '../../data/models/department_model.dart'; // Import Model

abstract class EmployeeRepository {
  // Hàm tạo nhân viên
  Future<bool> createEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String dob,
    required String role,
    required int departmentId,
    required String currentUserId,
    required String password, // [MỚI] Thêm tham số này
  });

  // [Mới] Hàm lấy danh sách nhân viên
  Future<List<EmployeeModel>> getEmployees(String currentUserId);

  // [Mới] Hàm lấy danh sách phòng ban
  Future<List<DepartmentModel>> getDepartments();
  Future<bool> updateEmployee(
    String id,
    String fullName,
    String phone,
    String dob,
  );
}
