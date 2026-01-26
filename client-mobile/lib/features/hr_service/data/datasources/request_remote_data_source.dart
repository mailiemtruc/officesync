import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/request_model.dart';
// [MỚI] Import Storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RequestRemoteDataSource {
  static const String baseUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/requests';
  static const String storageUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/files/upload';

  // [MỚI] Khai báo Storage
  final _storage = const FlutterSecureStorage();

  // [MỚI] Hàm Helper lấy Header
  Future<Map<String, String>> _getHeaders(String userId) async {
    String? token = await _storage.read(key: 'auth_token');
    return {
      "Content-Type": "application/json",
      "X-User-Id": userId,
      "Authorization": "Bearer $token", // QUAN TRỌNG
    };
  }

  // 1. TẠO ĐƠN
  Future<bool> createRequest({
    required String userId,
    required String type,
    required String startTime,
    required String endTime,
    required String reason,
    double? durationVal,
    String? durationUnit,
    String? evidenceUrl,
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
        "evidenceUrl": evidenceUrl,
      };

      print("--> Sending Request Payload: $body");

      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.post(
        url,
        headers: headers,
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

  // 2. UPLOAD FILE
  Future<String> uploadFile(File file) async {
    try {
      print("--> Uploading to Storage: $storageUrl");

      var request = http.MultipartRequest('POST', Uri.parse(storageUrl));

      // [FIX] Thêm token vào header của MultipartRequest
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
        throw Exception("Upload failed: ${response.body}");
      }
    } catch (e) {
      print("Error uploading file: $e");
      rethrow;
    }
  }

  // 3. LẤY DANH SÁCH ĐƠN CỦA TÔI
  Future<List<RequestModel>> getMyRequests(
    String userId, {
    String? search,
    int? day,
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

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.get(uri, headers: headers);

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

  // 4. HỦY ĐƠN
  Future<bool> cancelRequest(String requestId, String userId) async {
    try {
      final url = Uri.parse('$baseUrl/$requestId');

      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete request: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 5. DUYỆT ĐƠN
  Future<bool> processRequest(
    String requestId,
    String approverId,
    String status,
    String comment,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/$requestId/process');
      print("--> Processing Request $requestId: $status");

      // [SỬA]
      final headers = await _getHeaders(approverId);

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"status": status, "comment": comment}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        String errorMessage = "Failed to process request";
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['message'] != null) {
            errorMessage = errorJson['message'];
          }
        } catch (_) {
          errorMessage = response.body;
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error processing request: $e");
      rethrow;
    }
  }

  // 6. LẤY CHI TIẾT ĐƠN
  Future<RequestModel?> getRequestById(String requestId, String userId) async {
    try {
      final url = Uri.parse('$baseUrl/$requestId');
      print("--> Fetching Request Detail: $url");

      // [SỬA]
      final headers = await _getHeaders(userId);

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RequestModel.fromJson(data);
      } else {
        print("Failed to load request detail: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching request detail: $e");
      return null;
    }
  }

  // 7. LẤY DANH SÁCH DUYỆT (MANAGER) - ĐÂY LÀ CHỖ GÂY LỖI 401 TRONG LOG CỦA BẠN
  Future<List<RequestModel>> getManagerRequests(
    String managerId, {
    String? search,
    int? day,
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

      final uri = Uri.parse(
        '$baseUrl/manager',
      ).replace(queryParameters: queryParams);

      print("--> [API CALL] GET $uri with User-Id: $managerId");

      // [SỬA] Dùng hàm _getHeaders (Đã bao gồm Token)
      final headers = await _getHeaders(managerId);

      final response = await http.get(uri, headers: headers);

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
