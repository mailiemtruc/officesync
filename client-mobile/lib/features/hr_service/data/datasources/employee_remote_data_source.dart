import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/employee_model.dart';
import '../models/department_model.dart';
import '../../../../core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EmployeeRemoteDataSource {
  final ApiClient _apiClient = ApiClient();
  static const String baseUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api';
  static const String _baseUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/employees';
  static const String storageUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/files/upload';

  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders(String userId) async {
    String? token = await _storage.read(key: 'auth_token');
    return {
      "Content-Type": "application/json",
      "X-User-Id": userId,
      "Authorization": "Bearer $token",
    };
  }

  Future<String?> createEmployee(
    EmployeeModel employee,
    int deptId,
    String creatorId,
    String password,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl?departmentId=$deptId');

      print("--> Creating Employee by User ID: $creatorId");

      Map<String, dynamic> bodyData = employee.toJson();
      bodyData['password'] = password;

      final headers = await _getHeaders(creatorId);

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('id')) {
          return data['id'].toString();
        }
        return null;
      } else {
        throw Exception('Failed to create employee: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<DepartmentModel>> getDepartments(String currentUserId) async {
    try {
      final url = Uri.parse('$baseUrl/departments');
      print("--> Fetching Departments from: $url");

      final headers = await _getHeaders(currentUserId);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DepartmentModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load departments: ${response.body}');
      }
    } catch (e) {
      print("Error fetching departments: $e");
      return [];
    }
  }

  // 3. LẤY DANH SÁCH NHÂN VIÊN
  Future<List<EmployeeModel>> getEmployees(String currentUserId) async {
    try {
      final url = Uri.parse(_baseUrl);
      print("--> Fetching Employees via: $url");

      final headers = await _getHeaders(currentUserId);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EmployeeModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load employees: ${response.body}');
      }
    } catch (e) {
      print("Error fetching employees: $e");
      return [];
    }
  }

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
    try {
      final url = Uri.parse('$_baseUrl/$id');

      final Map<String, dynamic> body = {
        "fullName": fullName,
        "phone": phone,
        "dateOfBirth": dob,
        if (email != null && email.isNotEmpty) "email": email,
        "avatarUrl": avatarUrl,
        if (status != null) "status": status,
        if (role != null) "role": role,
        if (departmentId != null) "departmentId": departmentId,
      };

      final headers = await _getHeaders(updaterId);

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['message'] ?? 'Update failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  // [MỚI] Tìm kiếm nhân viên
  Future<List<EmployeeModel>> searchEmployees(
    String currentUserId,
    String keyword,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/search?keyword=$keyword');
      print("--> Searching Employees: $url");

      // [SỬA] Dùng hàm _getHeaders
      final headers = await _getHeaders(currentUserId);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EmployeeModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search employees: ${response.body}');
      }
    } catch (e) {
      print("Error searching employees: $e");
      return [];
    }
  }

  /// Suggestion
  Future<List<EmployeeModel>> getEmployeeSuggestions(
    String currentUserId,
    String keyword,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/suggestion?keyword=$keyword');
      print("--> Fetching Suggestions: $url");

      final headers = await _getHeaders(currentUserId);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EmployeeModel.fromJson(json)).toList();
      } else {
        print("Backend Error: ${response.statusCode} - ${response.body}");
        throw Exception('Failed to load suggestions: ${response.body}');
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
      return [];
    }
  }

  // Lấy nhân viên theo ID phòng ban
  Future<List<EmployeeModel>> getEmployeesByDepartment(int departmentId) async {
    try {
      final url = Uri.parse('$_baseUrl/department/$departmentId');
      print("--> Fetching Members for Dept ID: $departmentId");

      String? token = await _storage.read(key: 'auth_token');
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EmployeeModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load department members: ${response.body}');
      }
    } catch (e) {
      print("Error fetching department members: $e");
      return [];
    }
  }

  // Xóa nhân viên
  Future<bool> deleteEmployee(String deleterId, String targetId) async {
    try {
      final url = Uri.parse('$_baseUrl/$targetId');
      print("--> Deleting Employee ID: $targetId by User: $deleterId");

      final headers = await _getHeaders(deleterId);

      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Delete Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Delete Error: $e");
      rethrow;
    }
  }

  // Upload File
  Future<String> uploadFile(File file) async {
    try {
      final url = Uri.parse(storageUrl);
      print("--> Uploading file to: $storageUrl");

      var request = http.MultipartRequest('POST', url);

      String? token = await _storage.read(key: 'auth_token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['url'];
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      print("Error uploading file: $e");
      rethrow;
    }
  }

  // Kiểm tra quyền HR
  Future<bool> checkHrPermission(int userId) async {
    try {
      String? token = await _storage.read(key: 'auth_token');

      final response = await _apiClient.get(
        '$_baseUrl/check-hr-permission',
        options: Options(
          headers: {'X-User-Id': userId, 'Authorization': 'Bearer $token'},
        ),
      );

      if (response.data != null &&
          response.data['canAccessAttendance'] != null) {
        return response.data['canAccessAttendance'] as bool;
      }
      return false;
    } catch (e) {
      print("Error checking HR permission: $e");
      return false;
    }
  }
}
