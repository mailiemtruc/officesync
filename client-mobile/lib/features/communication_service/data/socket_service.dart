import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  StompClient? _client;

  // ⚠️ Đổi IP theo máy của bạn (Máy thật dùng IP LAN, Máy ảo dùng 10.0.2.2)
  // Lưu ý: WebSocket dùng giao thức ws://
  final String _socketUrl = "ws://10.0.2.2:8000/ws-comm";

  void connect({required Function() onConnected}) {
    if (_client != null && _client!.connected) return;

    _client = StompClient(
      config: StompConfig(
        url: _socketUrl,
        onConnect: (StompFrame frame) {
          print("✅ [Socket] Connected!");
          onConnected();
        },
        onWebSocketError: (dynamic error) => print("❌ [Socket] Error: $error"),
      ),
    );

    _client?.activate();
  }

  // Hàm đăng ký kênh Công ty (để nhận bài viết mới)
  void subscribeToCompany(
    int companyId,
    Function(Map<String, dynamic>) onNewPost,
  ) {
    _client?.subscribe(
      destination: '/topic/company/$companyId',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final data = jsonDecode(frame.body!);
          print("🔔 [Socket] Có bài mới!");
          onNewPost(data);
        }
      },
    );
  }

  // Hàm đăng ký kênh Bài viết (để nhận comment mới)
  void subscribeToPost(
    int postId,
    Function(Map<String, dynamic>) onNewComment,
  ) {
    _client?.subscribe(
      destination: '/topic/post/$postId',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final data = jsonDecode(frame.body!);
          print("🔔 [Socket] Có comment mới!");
          onNewComment(data);
        }
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
  }
}
