// features/attendance_service/data/attendance_api.dart

import 'package:dio/dio.dart'; // Import để dùng Options set Header
import '../../../core/api/api_client.dart';
import 'models/attendance_model.dart';

class AttendanceApi {
  final ApiClient _apiClient = ApiClient();

  // URL Service Chấm công (Port 8083)
  // Nếu chạy máy thật: thay 10.0.2.2 bằng IP LAN (VD: 192.168.1.x)
  static const String _serviceUrl = 'http://10.0.2.2:8083/api/attendance';

  // 1. Hàm Check-in
  Future<AttendanceModel> checkIn(
    int companyId,
    double lat,
    double lng,
    String bssid,
  ) async {
    try {
      final response = await _apiClient.post(
        '$_serviceUrl/check-in',
        data: {
          "companyId": companyId,
          "latitude": lat,
          "longitude": lng,
          "bssid": bssid,
        },
      );

      return AttendanceModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // 2. Hàm lấy lịch sử chấm công cá nhân (User thường)
  Future<List<AttendanceModel>> getHistory(
    int userId,
    int month,
    int year,
  ) async {
    try {
      final response = await _apiClient.get(
        '$_serviceUrl/history',
        queryParameters: {'month': month, 'year': year},
        options: Options(headers: {'X-User-Id': userId}),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => AttendanceModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

  // 3. [QUAN TRỌNG] Hàm lấy bảng công tổng hợp (Dành cho Manager/Admin)
  Future<List<AttendanceModel>> getManagerAllAttendance(
    int userId, // [THAM SỐ 1]: int
    String userRole, // [THAM SỐ 2]: String
    int month, // [THAM SỐ 3]: int
    int year, // [THAM SỐ 4]: int
  ) async {
    try {
      final response = await _apiClient.get(
        '$_serviceUrl/manager/list',
        queryParameters: {'month': month, 'year': year},
        options: Options(
          headers: {
            'X-User-Id': userId, // Truyền ID người quản lý
            'X-User-Role': userRole, // Truyền Role để Backend check quyền
          },
        ),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => AttendanceModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print("Manager Fetch Error: $e");
      return [];
    }
  }
}
