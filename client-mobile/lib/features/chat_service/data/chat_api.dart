import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/chat_message.dart';
import 'models/chat_room.dart';

class ChatApi {
  // ⚠️ QUAN TRỌNG:
  // - Máy ảo Android: 10.0.2.2
  // - Máy thật: Nhập IP LAN của máy tính (VD: 192.168.1.10)
  static const String baseUrl = 'http://10.0.2.2:8092';

  // URL Socket (không cần /websocket ở cuối nếu cấu hình Spring Boot là /ws)
  static const String wsUrl = 'ws://10.0.2.2:8092/ws/websocket';
  final _storage = const FlutterSecureStorage();

  // Helper lấy Header chứa Token
  Future<Map<String, String>> _getHeaders() async {
    // [SỬA] Đổi key thành 'auth_token'
    String? token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Lấy danh sách người đã chat gần đây (Sidebar)
  Future<List<ChatMessage>> fetchRecentConversations(String myId) async {
    try {
      final headers = await _getHeaders();
      // Server yêu cầu header X-User-Id hoặc lấy từ Token.
      // Vì mình đã code Backend lấy từ Token nên API này an toàn.
      final url = Uri.parse('$baseUrl/api/conversations');
      // Thêm header X-User-Id nếu Backend yêu cầu (tùy logic Controller)
      final newHeaders = {...headers, 'X-User-Id': myId};

      final response = await http.get(url, headers: newHeaders);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((item) => ChatMessage.fromJson(item, myId)).toList();
      }
    } catch (e) {
      print("❌ Lỗi Sidebar: $e");
    }
    return [];
  }

  // 2. Lấy lịch sử chat với 1 người
  Future<List<ChatMessage>> fetchHistory(String myId, String partnerId) async {
    try {
      final headers = await _getHeaders();
      final newHeaders = {...headers, 'X-User-Id': myId};

      final url = Uri.parse('$baseUrl/api/messages/$partnerId');

      final response = await http.get(url, headers: newHeaders);

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(response.body);
        return body.map((item) => ChatMessage.fromJson(item, myId)).toList();
      }
    } catch (e) {
      print("❌ Lỗi History: $e");
    }
    return [];
  }

  // 3. Lấy danh sách toàn bộ nhân viên (Danh bạ)
  Future<List<ChatUser>> fetchAllUsers() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/users');

      print("🚀 [Flutter] Đang gọi API: $url"); // <--- DEBUG 1
      print("🚀 [Flutter] Token: ${headers['Authorization']}"); // <--- DEBUG 2

      final response = await http.get(url, headers: headers);

      print(
        "👉 [Flutter] KẾT QUẢ STATUS CODE: ${response.statusCode}",
      ); // <--- QUAN TRỌNG NHẤT

      if (response.statusCode == 200) {
        print("✅ [Flutter] Body: ${response.body}"); // Xem dữ liệu trả về có gì
        List<dynamic> body = json.decode(response.body);
        return body
            .map(
              (item) => ChatUser(
                id: item['id'].toString(),
                name: item['fullName'] ?? "No Name",
                email: item['email'] ?? "",
                avatar:
                    item['avatarUrl'] ??
                    "https://i.pravatar.cc/150?u=${item['id']}",
                isOnline: item['isOnline'] ?? false,
              ),
            )
            .toList();
      } else {
        print(
          "❌ [Flutter] Lỗi Server trả về: ${response.body}",
        ); // Xem lỗi chi tiết
      }
    } catch (e) {
      print("❌ [Flutter] Lỗi Exception (Mạng/Code): $e");
    }
    return [];
  }

  // 1. Lấy danh sách phòng chat (Gồm cả 1-1 và Group)
  Future<List<ChatRoom>> fetchMyRooms() async {
    try {
      final headers = await _getHeaders();
      // API này trả về List<ChatRoom>
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/rooms'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        return body.map((e) => ChatRoom.fromJson(e)).toList();
      }
    } catch (e) {
      print("Error fetchMyRooms: $e");
    }
    return [];
  }

  // 2. Tạo nhóm mới
  Future<bool> createGroup(String groupName, List<String> memberIds) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        "groupName": groupName,
        "memberIds": memberIds.map((e) => int.parse(e)).toList(),
      });

      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/groups'),
        headers: headers,
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error createGroup: $e");
      return false;
    }
  }

  Future<int?> getPrivateRoomId(String partnerId) async {
    try {
      final headers = await _getHeaders();
      // Gọi API vừa tạo ở Bước 2
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/private-room/$partnerId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final body = json.decode(utf8.decode(response.bodyBytes));
        return body['id']; // Trả về Room ID
      }
    } catch (e) {
      print("Error getPrivateRoomId: $e");
    }
    return null;
  }

  // Hàm lấy lịch sử tin nhắn theo Room ID
  Future<List<ChatMessage>> fetchMessagesByRoom(int roomId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/messages/$roomId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> body = json.decode(utf8.decode(response.bodyBytes));
        // Lấy userId hiện tại để xác định isMe
        String? myId = await _storage.read(key: 'userId');
        return body.map((e) => ChatMessage.fromJson(e, myId ?? "")).toList();
      }
    } catch (e) {
      print("Lỗi lấy lịch sử chat: $e");
    }
    return [];
  }

  // Lấy thông tin chi tiết phòng (Members, Admin...)
  Future<Map<String, dynamic>?> fetchRoomInfo(int roomId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/room/$roomId/info'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      print("Lỗi fetchRoomInfo: $e");
    }
    return null;
  }
}

// Model đơn giản dùng cho Danh bạ (Paste luôn xuống cuối file chat_api.dart cũng được)
class ChatUser {
  final String id;
  final String name;
  final String email;
  final String avatar;
  final bool isOnline; // <--- Thêm dòng này

  ChatUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    this.isOnline = false, // <--- Mặc định false
  });
}
