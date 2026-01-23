import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiApi {
  // [QUAN TRỌNG]
  // - Nếu chạy máy ảo Android: dùng 'http://10.0.2.2:5000'
  // - Nếu chạy máy thật (cắm cáp): dùng IP LAN của máy tính (VD: 'http://192.168.1.5:5000')
  static const String _baseUrl = 'http://10.0.2.2:8000/api/ai';

  final _storage = const FlutterSecureStorage();

  Future<String> sendMessage(String message) async {
    try {
      // 1. Lấy User ID từ storage để AI biết ai đang hỏi
      String? userId = await _storage.read(key: 'userId');
      if (userId == null) return "Lỗi: Không tìm thấy thông tin người dùng.";

      // 2. Gọi API Python
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userId": int.parse(userId), "message": message}),
      );

      // 3. Xử lý kết quả
      if (response.statusCode == 200) {
        // Python trả về UTF-8, decode để không lỗi font
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        // [SỬA TẠI ĐÂY] Thêm .trim() để cắt sạch khoảng trắng/xuống dòng thừa
        return (data['reply'] ?? "").toString().trim();
      } else {
        return "AI Server Error (${response.statusCode}): Vui lòng thử lại sau.";
      }
    } catch (e) {
      print("AI Error: $e");
      return "Không thể kết nối đến Trợ lý ảo. Hãy đảm bảo bạn đã bật server Python.";
    }
  }
}
