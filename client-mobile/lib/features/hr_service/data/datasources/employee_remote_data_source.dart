import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/employee_model.dart';
import '../models/department_model.dart';
import '../../../../core/api/api_client.dart';
import 'package:dio/dio.dart';
import '../models/employee_model.dart';

class EmployeeRemoteDataSource {
  final ApiClient _apiClient = ApiClient();
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  static const String _baseUrl = 'http://10.0.2.2:8000/api/employees';
  static const String storageUrl = 'http://10.0.2.2:8000/api/files/upload';

  Future<String?> createEmployee(
    EmployeeModel employee,
    int deptId,
    String creatorId,
    String password,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/employees?departmentId=$deptId');

      print("--> Creating Employee by User ID: $creatorId");

      Map<String, dynamic> bodyData = employee.toJson();
      bodyData['password'] = password;

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "X-User-Id": creatorId},
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('id')) {
          return data['id'].toString();
        }
        return null; // Tạo thành công nhưng server không trả về ID
      } else {
        throw Exception('Failed to create employee: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. LẤY DANH SÁCH PHÒNG BAN (Đã sửa bảo mật)
  Future<List<DepartmentModel>> getDepartments(String currentUserId) async {
    // [MỚI] Thêm tham số
    try {
      final url = Uri.parse('$baseUrl/departments');
      print("--> Fetching Departments from: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id":
              currentUserId, // [QUAN TRỌNG] Gửi ID để Backend lọc công ty
        },
      );

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
      // Backend có thể lọc theo công ty dựa trên X-User-Id
      final url = Uri.parse('$baseUrl/employees');
      print("--> Fetching Employees via: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": currentUserId,
        },
      );

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
    String updaterId, // [MỚI] Thêm tham số này để biết ai là người sửa
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
      final url = Uri.parse('$baseUrl/employees/$id');

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

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id":
              updaterId, // [QUAN TRỌNG] Gửi ID người thực hiện lên Header
        },
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
      // Gọi vào endpoint /search
      final url = Uri.parse('$baseUrl/employees/search?keyword=$keyword');
      print("--> Searching Employees: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": currentUserId, // Backend dùng cái này để lọc công ty
        },
      );

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

  /// [MỚI - QUAN TRỌNG] Hàm Suggestion dùng cho Select Manager / Add Members
  Future<List<EmployeeModel>> getEmployeeSuggestions(
    String currentUserId,
    String keyword,
  ) async {
    try {
      // SỬA LẠI DÒNG NÀY: Thêm /employees
      final url = Uri.parse('$baseUrl/employees/suggestion?keyword=$keyword');

      print("--> Fetching Suggestions: $url"); // In ra log để kiểm tra

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": currentUserId,
        },
      );

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

  // [MỚI] Lấy nhân viên theo ID phòng ban (Server-side filter)
  Future<List<EmployeeModel>> getEmployeesByDepartment(int departmentId) async {
    try {
      final url = Uri.parse('$baseUrl/employees/department/$departmentId');
      print("--> Fetching Members for Dept ID: $departmentId");

      final response = await http.get(
        url,
      ); // API này public trong nội bộ cty, hoặc thêm header nếu cần

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

  // [SỬA LẠI] Thêm tham số deleterId
  Future<bool> deleteEmployee(String deleterId, String targetId) async {
    try {
      final url = Uri.parse('$baseUrl/employees/$targetId');
      print("--> Deleting Employee ID: $targetId by User: $deleterId");

      final response = await http.delete(
        url,
        // [QUAN TRỌNG] Bổ sung Header X-User-Id
        headers: {"Content-Type": "application/json", "X-User-Id": deleterId},
      );

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

  // [MỚI] Hàm Upload File chuẩn chỉnh
  Future<String> uploadFile(File file) async {
    try {
      final url = Uri.parse(storageUrl);
      print("--> Uploading file to: $storageUrl");

      var request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['url']; // Trả về URL ảnh
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      print("Error uploading file: $e");
      rethrow;
    }
  }

  // [MỚI] Hàm kiểm tra quyền HR Manager
  Future<bool> checkHrPermission(int userId) async {
    try {
      final response = await _apiClient.get(
        '$_baseUrl/check-hr-permission',
        options: Options(headers: {'X-User-Id': userId}),
      );

      // Backend trả về: { "canAccessAttendance": true/false }
      if (response.data != null &&
          response.data['canAccessAttendance'] != null) {
        return response.data['canAccessAttendance'] as bool;
      }
      return false;
    } catch (e) {
      print("Error checking HR permission: $e");
      return false; // Mặc định chặn nếu lỗi mạng
    }
  }
}
