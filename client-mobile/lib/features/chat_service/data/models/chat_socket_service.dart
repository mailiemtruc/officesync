import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:officesync/features/chat_service/data/chat_api.dart';

class ChatSocketService {
  StompClient? stompClient;
  final _storage = const FlutterSecureStorage();

  // Callback để báo tin nhắn về UI
  Function(dynamic)? onMessageReceived;

  void connect(String myId) async {
    // [SỬA] Đổi key thành 'auth_token' cho khớp với Login
    String? token = await _storage.read(key: 'auth_token');

    if (token == null) {
      print("❌ Chưa có Token (auth_token is null)");
      return;
    }

    // Cấu hình cho bản 1.0.0
    stompClient = StompClient(
      config: StompConfig(
        url: ChatApi.wsUrl,
        onConnect: (StompFrame frame) {
          print("✅ Socket Connected!");
          _subscribe(myId);
        },
        onWebSocketError: (error) => print("❌ Socket Error: $error"),
        onStompError: (frame) => print("❌ Stomp Error: ${frame.body}"),

        // [QUAN TRỌNG] Gửi Token trong Header lúc bắt tay
        // Spring Boot Security sẽ chặn ở đây nếu không có Token
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );

    stompClient!.activate();
  }

  void _subscribe(String myId) {
    // SỬA LẠI: Lắng nghe kênh notifications thay vì messages cũ
    stompClient!.subscribe(
      destination: '/user/queue/notifications',
      callback: (StompFrame frame) {
        if (frame.body != null && onMessageReceived != null) {
          print("📩 Nhận tin mới (Sidebar): ${frame.body}");
          final data = json.decode(frame.body!);
          onMessageReceived!(data);
        }
      },
    );
  }

  void sendMessage(String recipientId, String content) {
    if (stompClient == null || !stompClient!.connected) {
      print("⚠️ Socket chưa kết nối, không thể gửi tin.");
      return;
    }

    stompClient!.send(
      destination:
          '/app/chat.sendMessage', // Khớp với @MessageMapping bên Controller
      body: json.encode({
        'recipientId': recipientId, // Gửi ID người nhận
        'content': content,
        // Không gửi senderId, Server tự lấy từ Token (An toàn)
      }),
    );
  }

  void disconnect() {
    stompClient?.deactivate();
  }
}
