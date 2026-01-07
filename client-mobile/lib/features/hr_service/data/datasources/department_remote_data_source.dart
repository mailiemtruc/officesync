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

  // [SỬA] Thêm tham số userId để gửi Header
  Future<bool> updateDepartment(
    String userId, // [MỚI]
    int id,
    String name,
    String? managerId,
    bool isHr, // [MỚI] Thêm tham số
  ) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      final body = {
        "name": name,
        "managerId": managerId != null ? int.tryParse(managerId) : null,
        "isHr": isHr, // [MỚI] Gửi lên
      };

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": userId, // [MỚI]
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  // [SỬA] Thêm tham số userId
  Future<bool> deleteDepartment(String userId, int id) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      final response = await http.delete(
        url,
        headers: {"X-User-Id": userId}, // [MỚI]
      );
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

  // [MỚI] Lấy thông tin phòng HR từ Server
  Future<DepartmentModel?> getHrDepartment(String userId) async {
    try {
      // Gọi vào endpoint /hr vừa tạo ở Backend
      final url = Uri.parse('$baseUrl/hr');
      print("--> Fetching HR Department info...");

      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json", "X-User-Id": userId},
      );

      if (response.statusCode == 200) {
        return DepartmentModel.fromJson(jsonDecode(response.body));
      } else {
        print("Failed to fetch HR Dept: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching HR Dept: $e");
      return null;
    }
  }
}
