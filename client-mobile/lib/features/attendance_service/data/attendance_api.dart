// features/attendance_service/data/attendance_api.dart

import 'package:dio/dio.dart'; // Import để dùng Options set Header
import '../../../core/api/api_client.dart';
import 'models/attendance_model.dart';

class AttendanceApi {
  final ApiClient _apiClient = ApiClient();

  // URL Service Chấm công (Port 8083)
  static const String _serviceUrl = 'http://10.0.2.2:8083/api/attendance';

  // 1. Hàm Check-in (Giữ nguyên)
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

  // 2. [ĐÃ SỬA] Hàm lấy lịch sử chấm công theo Tháng/Năm
  Future<List<AttendanceModel>> getHistory(
    int userId,
    int month,
    int year,
  ) async {
    try {
      final response = await _apiClient.get(
        '$_serviceUrl/history',
        // [MỚI] Truyền tháng và năm lên Server qua Query Params
        // URL thực tế sẽ là: .../history?month=1&year=2026
        queryParameters: {'month': month, 'year': year},
        // Truyền User ID vào Header
        options: Options(headers: {'X-User-Id': userId}),
      );

      // Convert dữ liệu JSON trả về (List) thành List<AttendanceModel>
      if (response.data is List) {
        return (response.data as List)
            .map((e) => AttendanceModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      // Nếu lỗi thì trả về danh sách rỗng để không crash app
      print("Error fetching history: $e");
      return [];
    }
  }

  // [MỚI] Hàm lấy bảng công tổng hợp (Dành cho Manager)
  Future<List<AttendanceModel>> getManagerAllAttendance(
    String userRole,
    int month,
    int year,
  ) async {
    try {
      final response = await _apiClient.get(
        '$_serviceUrl/manager/list',
        queryParameters: {'month': month, 'year': year},
        // [QUAN TRỌNG] Gửi Role lên để Backend kiểm tra
        options: Options(headers: {'X-User-Role': userRole}),
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => AttendanceModel.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print("Error fetching manager data: $e");
      rethrow; // Ném lỗi để UI xử lý (hiện thông báo cấm truy cập)
    }
  }
}
