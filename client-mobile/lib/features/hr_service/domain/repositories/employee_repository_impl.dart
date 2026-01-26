import '../../domain/repositories/employee_repository.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';
import 'dart:io';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;

  EmployeeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String?> createEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String dob,
    required String role,
    required int departmentId,
    required String currentUserId,
    required String password,
  }) async {
    final employee = EmployeeModel(
      fullName: fullName,
      email: email,
      phone: phone,
      dateOfBirth: dob,
      role: role,
      status: "ACTIVE",
    );

    return await remoteDataSource.createEmployee(
      employee,
      departmentId,
      currentUserId,
      password,
    );
  }

  @override
  Future<List<EmployeeModel>> getEmployees(String currentUserId) async {
    return await remoteDataSource.getEmployees(currentUserId);
  }

  @override
  Future<List<DepartmentModel>> getDepartments(String currentUserId) async {
    return await remoteDataSource.getDepartments(currentUserId);
  }

  @override
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
  }) async {
    return await remoteDataSource.updateEmployee(
      updaterId,
      id,
      fullName,
      phone,
      dob,
      email: email,
      avatarUrl: avatarUrl,
      status: status,
      role: role,
      departmentId: departmentId,
    );
  }

  @override
  Future<bool> deleteEmployee(String deleterId, String targetId) async {
    return await remoteDataSource.deleteEmployee(deleterId, targetId);
  }

  @override
  Future<List<EmployeeModel>> searchEmployees(
    String currentUserId,
    String keyword,
  ) async {
    return await remoteDataSource.searchEmployees(currentUserId, keyword);
  }

  @override
  Future<List<EmployeeModel>> getEmployeeSuggestions(
    String currentUserId,
    String keyword,
  ) async {
    return await remoteDataSource.getEmployeeSuggestions(
      currentUserId,
      keyword,
    );
  }

  @override
  Future<List<EmployeeModel>> getEmployeesByDepartment(int departmentId) async {
    return await remoteDataSource.getEmployeesByDepartment(departmentId);
  }

  @override
  Future<String> uploadFile(File file) async {
    return await remoteDataSource.uploadFile(file);
  }
}
