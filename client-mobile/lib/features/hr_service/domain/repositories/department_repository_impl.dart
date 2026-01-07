import '../../domain/repositories/department_repository.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../data/models/department_model.dart';

class DepartmentRepositoryImpl implements DepartmentRepository {
  final DepartmentRemoteDataSource remoteDataSource;

  DepartmentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<bool> createDepartment(
    DepartmentModel department,
    String creatorId,
  ) async {
    return await remoteDataSource.createDepartment(department, creatorId);
  }

  @override
  Future<bool> updateDepartment(
    String userId,
    int id,
    String name,
    String? managerId,
    bool isHr,
  ) async {
    return await remoteDataSource.updateDepartment(
      userId,
      id,
      name,
      managerId,
      isHr,
    );
  }

  @override
  Future<bool> deleteDepartment(String userId, int id) async {
    return await remoteDataSource.deleteDepartment(userId, id);
  }

  @override
  Future<List<DepartmentModel>> searchDepartments(
    String userId,
    String keyword,
  ) async {
    return await remoteDataSource.searchDepartments(userId, keyword);
  }

  @override
  Future<DepartmentModel?> getHrDepartment(String userId) async {
    return await remoteDataSource.getHrDepartment(userId);
  }
}
