import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _client;

  // IP Backend (Dùng 10.0.2.2 cho Android Emulator)
  final String _socketUrl = 'ws://10.0.2.2:8081/ws-hr/websocket';

  bool get isConnected => _client?.connected ?? false;

  // 1. Hàm kết nối (Gọi 1 lần duy nhất khi Login thành công hoặc mở App)
  void connect() {
    if (_client != null && _client!.connected) return;

    _client = StompClient(
      config: StompConfig(
        url: _socketUrl,
        onConnect: (StompFrame frame) {
          debugPrint("✅ [WS] Global Connected!");
        },
        onWebSocketError: (dynamic error) => debugPrint("❌ [WS] Error: $error"),
        onDisconnect: (f) => debugPrint("🔌 [WS] Disconnected"),
        reconnectDelay: const Duration(seconds: 5), // Tự động kết nối lại
      ),
    );

    _client?.activate();
  }

  // 2. Ngắt kết nối (Gọi khi Logout)
  void disconnect() {
    _client?.deactivate();
    _client = null;
    debugPrint("🛑 [WS] Deactivated Global");
  }

  // 3. Hàm đăng ký nhận tin (Các màn hình gọi hàm này)
  // Trả về: Hàm unsubscribe (để màn hình gọi khi dispose)
  dynamic subscribe(String destination, Function(dynamic) callback) {
    if (_client == null) {
      debugPrint("⚠️ [WS] Client is null, attempting to connect...");
      connect(); // Thử kết nối lại nếu chưa có
    }

    // Lưu ý: StompClient có thể queue subscription nếu chưa connect xong
    return _client?.subscribe(
      destination: destination,
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            // Trường hợp 1: Backend gửi JSON -> Parse thành Map
            final data = jsonDecode(frame.body!);
            callback(data);
          } catch (e) {
            // Trường hợp 2: Backend gửi String thô (VD: "NEW_REQUEST") -> Trả về nguyên văn
            callback(frame.body);
          }
        }
      },
    );
  }
}
