import 'dart:io';

import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';

abstract class EmployeeRepository {
  Future<String?> createEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String dob,
    required String role,
    required int departmentId,
    required String currentUserId,
    required String password,
  });

  Future<String> uploadFile(File file);

  Future<List<EmployeeModel>> getEmployees(String currentUserId);

  Future<List<DepartmentModel>> getDepartments(String currentUserId);

  Future<bool> updateEmployee(
    String updaterId,
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

  Future<bool> deleteEmployee(String deleterId, String targetId);

  Future<List<EmployeeModel>> searchEmployees(
    String currentUserId,
    String keyword,
  );

  Future<List<EmployeeModel>> getEmployeeSuggestions(
    String currentUserId,
    String keyword,
  );

  Future<List<EmployeeModel>> getEmployeesByDepartment(int departmentId);
}
