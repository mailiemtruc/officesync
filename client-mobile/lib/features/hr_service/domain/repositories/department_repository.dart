import '../../data/models/department_model.dart';
import '../../data/datasources/department_remote_data_source.dart';

class DepartmentRepository {
  final DepartmentRemoteDataSource remoteDataSource;

  DepartmentRepository({required this.remoteDataSource});

  Future<bool> createDepartment(
    DepartmentModel department,
    String creatorId,
  ) async {
    return await remoteDataSource.createDepartment(department, creatorId);
  }

  // [SỬA] Thêm tham số userId
  Future<bool> updateDepartment(
    String userId, // [MỚI]
    int id,
    String name,
    String description,
    String? managerId,
    bool isHr, // [MỚI]
  ) async {
    return await remoteDataSource.updateDepartment(
      userId, // [MỚI]
      id,
      name,
      description,
      managerId,
      isHr, // [MỚI]
    );
  }

  // [SỬA] Thêm tham số userId
  Future<bool> deleteDepartment(String userId, int id) async {
    return await remoteDataSource.deleteDepartment(userId, id);
  }

  // Thêm hàm này vào class DepartmentRepository
  Future<List<DepartmentModel>> searchDepartments(
    String userId,
    String keyword,
  ) async {
    return await remoteDataSource.searchDepartments(userId, keyword);
  }

  // [MỚI]
  Future<DepartmentModel?> getHrDepartment(String userId) async {
    return await remoteDataSource.getHrDepartment(userId);
  }
}
