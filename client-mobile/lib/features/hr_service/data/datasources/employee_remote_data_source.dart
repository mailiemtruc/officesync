import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/employee_model.dart';
import '../models/department_model.dart';

class EmployeeRemoteDataSource {
  static const String baseUrl = 'http://10.0.2.2:8081/api';

  // 1. TẠO NHÂN VIÊN
  Future<bool> createEmployee(
    EmployeeModel employee,
    int deptId,
    String creatorId,
    String password, // [MỚI] Nhận password
  ) async {
    try {
      final url = Uri.parse('$baseUrl/employees?departmentId=$deptId');

      print("--> Creating Employee by User ID: $creatorId");

      Map<String, dynamic> bodyData = employee.toJson();
      bodyData['password'] = password; // Nhét mật khẩu vào JSON

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": creatorId, // Header để Backend nhận diện công ty
        },
        body: jsonEncode(bodyData), // Gửi Map đã có password
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Server Error: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. LẤY DANH SÁCH PHÒNG BAN
  Future<List<DepartmentModel>> getDepartments() async {
    try {
      final url = Uri.parse('$baseUrl/departments');
      print("--> Fetching Departments from: $url");

      final response = await http.get(url);

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

  // 4. CẬP NHẬT NHÂN VIÊN
  Future<bool> updateEmployee(String id, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/employees/$id');
      print("--> Updating Employee ID: $id");

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update: ${response.body}');
      }
    } catch (e) {
      print("Update Error: $e");
      rethrow;
    }
  }
}
