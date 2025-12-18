import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/department_model.dart';

class DepartmentRemoteDataSource {
  static const String baseUrl = 'http://10.0.2.2:8081/api/departments';

  Future<bool> createDepartment(
    DepartmentModel department,
    String creatorId,
  ) async {
    try {
      final url = Uri.parse(baseUrl);

      print("--> Creating Dept: ${department.name} by User: $creatorId");
      print("--> Payload: ${jsonEncode(department.toJson())}");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": creatorId, // Header quan trọng
        },
        body: jsonEncode(department.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to create department: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
