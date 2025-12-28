// File: lib/data/datasources/request_remote_data_source.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/request_model.dart'; // Giả sử bạn có model này hoặc dùng Map

class RequestRemoteDataSource {
  static const String baseUrl = 'http://10.0.2.2:8081/api/requests';
  // Service lưu trữ (Storage) - Port 8090
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

  // 2. [MỚI] LẤY DANH SÁCH ĐƠN CỦA TÔI
  Future<List<RequestModel>> getMyRequests(String userId) async {
    try {
      // Backend thường có endpoint lấy list theo user ID từ header hoặc query param
      // Giả sử Backend trả về list tại GET /api/requests (filter theo X-User-Id)
      final url = Uri.parse(baseUrl);

      final response = await http.get(
        url,
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
      return []; // Trả về rỗng nếu lỗi để không crash app
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
}
