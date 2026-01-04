import '../../data/models/department_model.dart';

abstract class DepartmentRepository {
  Future<bool> createDepartment(DepartmentModel department, String creatorId);

  Future<bool> updateDepartment(
    String userId,
    int id,
    String name,
    String description,
    String? managerId,
    bool isHr,
  );

  Future<bool> deleteDepartment(String userId, int id);

  Future<List<DepartmentModel>> searchDepartments(
    String userId,
    String keyword,
  );

  Future<DepartmentModel?> getHrDepartment(String userId);
}
