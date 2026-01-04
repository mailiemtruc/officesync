import 'dart:io';

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
  // [MỚI] Thêm hàm upload
  Future<String> uploadFile(File file);
  // [Mới] Hàm lấy danh sách nhân viên
  Future<List<EmployeeModel>> getEmployees(String currentUserId);

  // [SỬA] Thêm tham số currentUserId
  Future<List<DepartmentModel>> getDepartments(String currentUserId);

  Future<bool> updateEmployee(
    String updaterId, // [MỚI]
    String id,
    String fullName,
    String phone,
    String dob, {
    String? email,
    String? avatarUrl,
    String? status,
    String? role,
    int? departmentId,
  });
  // [SỬA] Thêm deleterId
  Future<bool> deleteEmployee(String deleterId, String targetId);

  // [SỬA LẠI ĐÚNG] Chỉ khai báo hàm, KHÔNG viết code xử lý (không có curly braces {})
  Future<List<EmployeeModel>> searchEmployees(
    String currentUserId,
    String keyword,
  );

  // [MỚI] Hàm lấy gợi ý nhân viên (Active, Valid Role)
  Future<List<EmployeeModel>> getEmployeeSuggestions(
    String currentUserId,
    String keyword,
  );

  Future<List<EmployeeModel>> getEmployeesByDepartment(int departmentId);
}
