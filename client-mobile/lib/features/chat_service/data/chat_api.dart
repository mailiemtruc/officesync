import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/chat_message.dart';

class ChatApi {
  // CẤU HÌNH IP SERVER Ở ĐÂY
  // Nếu chạy máy thật thì đổi thành IP LAN (vd: 192.168.1.x)
  static const String baseUrl = 'http://10.0.2.2:8092';
  static const String wsUrl = 'ws://10.0.2.2:8092/ws';

  // Hàm gọi API lấy lịch sử tin nhắn
  Future<List<ChatMessage>> fetchHistory(
    String senderId,
    String recipientId,
  ) async {
    final url = Uri.parse('$baseUrl/api/messages/$senderId/$recipientId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((item) => ChatMessage.fromJson(item)).toList();
      } else {
        print("Lỗi server: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Lỗi kết nối: $e");
      return [];
    }
  }
}
