import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/department_model.dart';
// [MỚI] Import Storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DepartmentRemoteDataSource {
  static const String baseUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/departments';

  // [MỚI] Khai báo Storage
  final _storage = const FlutterSecureStorage();

  // [MỚI] Hàm Helper lấy Header
  Future<Map<String, String>> _getHeaders(String userId) async {
    String? token = await _storage.read(key: 'auth_token');
    return {
      "Content-Type": "application/json",
      "X-User-Id": userId,
      "Authorization": "Bearer $token",
    };
  }

  Future<bool> createDepartment(
    DepartmentModel department,
    String creatorId,
  ) async {
    try {
      final url = Uri.parse(baseUrl);

      print("--> Creating Dept: ${department.name} by User: $creatorId");

      // [SỬA]
      final headers = await _getHeaders(creatorId);

      final response = await http.post(
        url,
        headers: headers,
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

  Future<bool> updateDepartment(
    String userId,
    int id,
    String name,
    String? managerId,
    bool isHr,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      final body = {
        "name": name,
        "managerId": managerId != null ? int.tryParse(managerId) : null,
        "isHr": isHr,
      };

      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteDepartment(String userId, int id) async {
    try {
      final url = Uri.parse('$baseUrl/$id');
      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.delete(url, headers: headers);
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DepartmentModel>> searchDepartments(
    String currentUserId,
    String keyword,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/search?keyword=$keyword');
      print("--> Searching Departments: $url");

      // [SỬA]
      final headers = await _getHeaders(currentUserId);

      final response = await http.get(url, headers: headers);

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

  Future<DepartmentModel?> getHrDepartment(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/hr');
      print("--> Fetching HR Department info...");

      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.get(url, headers: headers);

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
