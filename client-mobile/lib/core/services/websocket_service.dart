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

  // 1. Hàm kết nối
  void connect() {
    // Nếu đã kết nối rồi thì thôi
    if (_client != null && _client!.connected) return;

    // [QUAN TRỌNG] Hủy instance cũ nếu nó đang tồn tại nhưng bị lỗi kết nối
    if (_client != null) {
      _client!.deactivate();
    }

    _client = StompClient(
      config: StompConfig(
        url: _socketUrl,
        onConnect: (StompFrame frame) {
          debugPrint("✅ [WS] Global Connected!");
        },
        onWebSocketError: (dynamic error) => debugPrint("❌ [WS] Error: $error"),
        onDisconnect: (f) => debugPrint("🔌 [WS] Disconnected"),
        connectionTimeout: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client?.activate();
  }

  // 2. Ngắt kết nối
  void disconnect() {
    _client?.deactivate();
    _client = null;
    debugPrint("🛑 [WS] Deactivated Global");
  }

  // 3. Hàm đăng ký nhận tin (ĐÃ SỬA LỖI CRASH)
  dynamic subscribe(String destination, Function(dynamic) callback) {
    // Bước 1: Đảm bảo đã gọi kết nối
    if (_client == null || !_client!.isActive) {
      connect();
    }

    // Bước 2: Thử subscribe với Try-Catch
    try {
      return _client?.subscribe(
        destination: destination,
        callback: (StompFrame frame) {
          if (frame.body != null) {
            try {
              final data = jsonDecode(frame.body!);
              callback(data);
            } catch (e) {
              callback(frame.body);
            }
          }
        },
      );
    } catch (e) {
      // [FIX LỖI] Nếu gặp lỗi StompHandler was null -> Reset client và thử lại ngay lập tức
      debugPrint(
        "⚠️ [WS] Subscribe error: $e. Attempting to force reconnect...",
      );

      _client = null; // Xóa client lỗi
      connect(); // Tạo client mới và activate ngay

      // Thử subscribe lại lần nữa
      try {
        return _client?.subscribe(
          destination: destination,
          callback: (StompFrame frame) {
            if (frame.body != null) {
              try {
                final data = jsonDecode(frame.body!);
                callback(data);
              } catch (e) {
                callback(frame.body);
              }
            }
          },
        );
      } catch (e2) {
        debugPrint("❌ [WS] Retry failed: $e2");
        return null; // Trả về null để UI không bị crash app
      }
    }
  }
}
