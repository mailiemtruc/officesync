import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiApi {
  static const String _baseUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/ai';

  final _storage = const FlutterSecureStorage();

  Future<String> sendMessage(String message) async {
    try {
      // 1. [SỬA] Lấy cả User ID VÀ Token từ storage
      String? userId = await _storage.read(key: 'userId');
      String? token = await _storage.read(
        key: 'auth_token',
      ); // <--- THÊM DÒNG NÀY

      if (userId == null) return "Lỗi: Không tìm thấy thông tin người dùng.";

      // 2. Gọi API Python (Thêm Token vào Header)
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // <--- THÊM DÒNG QUAN TRỌNG NÀY
        },
        body: jsonEncode({"userId": int.parse(userId), "message": message}),
      );

      // 3. Xử lý kết quả
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return (data['reply'] ?? "").toString().trim();
      } else if (response.statusCode == 401) {
        return "Lỗi xác thực: Phiên đăng nhập hết hạn hoặc không hợp lệ.";
      } else {
        return "AI Server Error (${response.statusCode}): Vui lòng thử lại sau.";
      }
    } catch (e) {
      print("AI Error: $e");
      return "Không thể kết nối đến Trợ lý ảo. Hãy đảm bảo bạn đã bật server Python.";
    }
  }
}
