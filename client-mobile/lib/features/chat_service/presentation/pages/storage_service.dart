import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StorageService {
  // Thay PORT_CUA_BAN bằng port của Storage Service (VD: 8080 hoặc 9090)
  static const String uploadUrl = 'http://10.0.2.2:8090/api/files/upload';

  Future<String?> uploadImage(File imageFile) async {
    try {
      // 1. Tạo request Multipart (để gửi file)
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // 2. Đính kèm file vào request
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // 3. Gửi đi
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 4. Lấy URL trả về
        // Server trả về JSON: {"url": "http://..."}
        final data = json.decode(response.body);
        return data['url'];
      } else {
        print("❌ Upload lỗi: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Lỗi kết nối Storage: $e");
      return null;
    }
  }
}
