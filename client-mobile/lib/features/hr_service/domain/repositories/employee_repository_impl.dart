import '../../domain/repositories/employee_repository.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;

  EmployeeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<bool> createEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String dob,
    required String role,
    required int departmentId,
    required String currentUserId,
    required String password, // [MỚI] Nhận password
  }) async {
    final employee = EmployeeModel(
      fullName: fullName,
      email: email,
      phone: phone,
      dateOfBirth: dob,
      role: role,
      status: "ACTIVE",
    );

    // Truyền tiếp password xuống remote data source
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
  Future<List<DepartmentModel>> getDepartments() async {
    return await remoteDataSource.getDepartments();
  }

  // [SỬA] Cập nhật hàm này
  @override
  Future<bool> updateEmployee(
    String id,
    String fullName,
    String phone,
    String dob, {
    String? avatarUrl, // [MỚI] Nhận tham số từ UI
  }) async {
    // Gọi xuống Data Source với tham số mới
    return await remoteDataSource.updateEmployee(
      id,
      fullName,
      phone,
      dob,
      avatarUrl: avatarUrl, // Truyền tiếp
    );
  }
}
