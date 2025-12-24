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

  // [MỚI] Cập nhật phòng ban
  Future<bool> updateDepartment(
    int id,
    String name,
    String description,
    String? managerId,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      final body = {
        "name": name,
        "description": description,
        "managerId": managerId != null ? int.tryParse(managerId) : null,
      };

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // [MỚI] Xóa phòng ban
  Future<bool> deleteDepartment(int id) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      final response = await http.delete(url);
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // [MỚI] Tìm kiếm phòng ban
  Future<List<DepartmentModel>> searchDepartments(
    String currentUserId,
    String keyword,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/search?keyword=$keyword',
      ); // Lưu ý endpoint là /search
      print("--> Searching Departments: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": currentUserId,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DepartmentModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search departments: ${response.body}');
      }
    } catch (e) {
      print("Error searching departments: $e");
      return [];
    }
  }
}
