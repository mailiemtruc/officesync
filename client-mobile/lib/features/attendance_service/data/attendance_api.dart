// [QUAN TRỌNG] Đường dẫn import chính xác tới Core
import '../../../core/api/api_client.dart';
import 'models/attendance_model.dart';

class AttendanceApi {
  // 1. Tận dụng ApiClient của Core (Đã có sẵn Token & Header X-User-Id)
  final ApiClient _apiClient = ApiClient();

  // 2. Định nghĩa URL riêng cho Service Chấm công (Port 8083)
  // Lưu ý: ApiClient sẽ tự động override base URL 8080 nếu thấy http trong path
  static const String _serviceUrl = 'http://10.0.2.2:8083/api/attendance';

  /// Hàm Check-in
  Future<AttendanceModel> checkIn(double lat, double lng, String bssid) async {
    try {
      final response = await _apiClient.post(
        '$_serviceUrl/check-in',
        data: {"latitude": lat, "longitude": lng, "bssid": bssid},
      );

      // Parse dữ liệu trả về thành Model
      return AttendanceModel.fromJson(response.data);
    } catch (e) {
      // Lỗi sẽ được _handleError trong ApiClient xử lý và ném ra
      rethrow;
    }
  }
}
