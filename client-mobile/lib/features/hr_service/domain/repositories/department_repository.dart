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
}
