// File: lib/data/datasources/request_remote_data_source.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/request_model.dart'; // Giả sử bạn có model này hoặc dùng Map

class RequestRemoteDataSource {
  static const String baseUrl = 'http://10.0.2.2:8081/api/requests';
  static const String storageUrl = 'http://10.0.2.2:8090/api/files/upload';

  // 1. TẠO ĐƠN (Giữ nguyên, thêm evidenceUrl nếu cần)
  Future<bool> createRequest({
    required String userId,
    required String type,
    required String startTime,
    required String endTime,
    required String reason,
    double? durationVal,
    String? durationUnit,
    String? evidenceUrl, // [MỚI] Nhận chuỗi URL ảnh
  }) async {
    try {
      final url = Uri.parse(baseUrl);
      final body = {
        "type": type,
        "startTime": startTime,
        "endTime": endTime,
        "reason": reason,
        "durationVal": durationVal,
        "durationUnit": durationUnit,
        "evidenceUrl": evidenceUrl, // Gửi lên server HR
      };

      print("--> Sending Request Payload: $body");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json", "X-User-Id": userId},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to create request: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 2. [MỚI] UPLOAD FILE (Gọi sang Storage Service 8090)
  Future<String> uploadFile(File file) async {
    try {
      print("--> Uploading to Storage: $storageUrl");

      var request = http.MultipartRequest('POST', Uri.parse(storageUrl));
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        return data['url'];
      } else {
        throw Exception("Upload failed: ${response.body}");
      }
    } catch (e) {
      print("Error uploading file: $e");
      rethrow;
    }
  }

  // [CẬP NHẬT] LẤY DANH SÁCH ĐƠN CỦA TÔI (Có lọc)
  Future<List<RequestModel>> getMyRequests(
    String userId, {
    String? search,
    int? day, // <-- Thêm tham số day
    int? month,
    int? year,
  }) async {
    try {
      // Tạo map chứa tham số
      final queryParams = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (day != null) queryParams['day'] = day.toString();
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      // Ghép tham số vào URL: /api/requests?search=abc&month=10...
      // Lưu ý: baseUrl là '.../api/requests'
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "X-User-Id": userId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RequestModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load requests: ${response.body}');
      }
    } catch (e) {
      print("Error fetching requests: $e");
      return [];
    }
  }

  // [SỬA] Gọi API Xóa đơn (DELETE)
  Future<bool> cancelRequest(String requestId, String userId) async {
    try {
      // Endpoint mới: DELETE /api/requests/{id}
      final url = Uri.parse('$baseUrl/$requestId');

      final response = await http.delete(
        // Đổi thành http.delete
        url,
        headers: {"Content-Type": "application/json", "X-User-Id": userId},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete request: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // [MỚI] Hàm xử lý Duyệt/Từ chối
  Future<bool> processRequest(
    String requestId,
    String approverId,
    String status,
    String comment,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/$requestId/process');
      print("--> Processing Request $requestId: $status");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-User-Id": approverId, // Header xác thực người duyệt
        },
        body: jsonEncode({
          "status": status, // "APPROVED" hoặc "REJECTED"
          "comment": comment,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error processing request: $e");
      rethrow;
    }
  }

  // [CẬP NHẬT] LẤY DANH SÁCH DUYỆT (Manager) (Có lọc)
  Future<List<RequestModel>> getManagerRequests(
    String managerId, {
    String? search,
    int? day, // [MỚI]
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (day != null) queryParams['day'] = day.toString();
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();

      // URL: .../api/requests/manager?search=...
      final uri = Uri.parse(
        '$baseUrl/manager',
      ).replace(queryParameters: queryParams);

      print("--> [API CALL] GET $uri with User-Id: $managerId");

      final response = await http.get(
        uri,
        headers: {"Content-Type": "application/json", "X-User-Id": managerId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RequestModel.fromJson(json)).toList();
      } else {
        print("--> [API ERROR] ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("--> [API EXCEPTION] $e");
      return [];
    }
  }
}
