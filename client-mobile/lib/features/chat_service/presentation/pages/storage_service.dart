import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // ✅ 1. Import thêm cái này

class StorageService {
  // Thay IP nếu cần (Máy ảo: 10.0.2.2, Máy thật: IP LAN)
  static const String uploadUrl =
      'https://productional-wendell-nonexotic.ngrok-free.dev/api/files/upload';

  // ✅ 2. Khởi tạo Storage để lấy Token
  final _storage = const FlutterSecureStorage();

  Future<String?> uploadImage(File imageFile) async {
    try {
      print("🚀 [Storage] Đang upload ảnh: ${imageFile.path}");

      // ✅ 3. Lấy Token
      String? token = await _storage.read(key: 'auth_token');
      if (token == null) {
        print("❌ [Storage] Lỗi: Chưa có Token!");
        return null;
      }

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // ✅ 4. Gắn Token vào Header (QUAN TRỌNG NHẤT)
      request.headers.addAll({'Authorization': 'Bearer $token'});

      // Đính kèm file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Gửi đi
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("👉 [Storage] Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ [Storage] Upload thành công: ${data['url']}");
        return data['url'];
      } else {
        print("❌ [Storage] Upload thất bại: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ [Storage] Exception: $e");
      return null;
    }
  }
}
