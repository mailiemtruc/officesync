import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 1. Import thư viện bảo mật

class ApiClient {
  // ⚠️ QUAN TRỌNG:
  // - Nếu chạy máy ảo Android: Dùng 'http://10.0.2.2:8080/api'
  // - Nếu chạy máy ảo iOS: Dùng 'http://localhost:8080/api'
  // - Nếu chạy máy thật: Dùng IP LAN (ví dụ 'http://192.168.1.x:8080/api')

  static const String baseUrl = 'http://10.0.2.2:8080/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      // 🔴 SỬA Ở ĐÂY: Tăng thời gian chờ lên 60 giây (1 phút) 🔴
      // Để App không bị ngắt kết nối khi Server đang gửi mail (mất khoảng 10-20s)
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      // -----------------------------------------------------------
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Hàm POST (Đã nâng cấp để gửi kèm Token)
  Future<Response> post(String path, {Map<String, dynamic>? data}) async {
    try {
      // 2. Lấy Token từ bộ nhớ bảo mật (Secure Storage)
      const storage = FlutterSecureStorage();
      String? token = await storage.read(key: 'auth_token');

      // 3. Tạo options chứa Header mới
      Options options = Options(
        headers: {
          'Content-Type': 'application/json',
          // Nếu có token thì gắn vào Authorization
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      // 4. Gọi API với options mới
      final response = await _dio.post(path, data: data, options: options);
      return response;
    } on DioException catch (e) {
      // Xử lý lỗi từ Server trả về
      throw Exception(e.response?.data ?? "The server connection failed.");
    }
  }
}
