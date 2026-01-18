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

  // 1. Hàm kết nối (Được tối ưu để tránh tạo nhiều kết nối thừa)
  void connect() {
    // Nếu client đang tồn tại và đã kết nối -> Không làm gì cả
    if (_client != null && _client!.connected) return;

    // [QUAN TRỌNG] Hủy client cũ nếu nó đang bị treo hoặc lỗi
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
        // [QUAN TRỌNG] Tăng thời gian chờ và delay kết nối lại
        connectionTimeout: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
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

  // 3. Hàm đăng ký nhận tin (ĐÃ SỬA LỖI CRASH)
  // Chuyển thành async để có thể chờ kết nối nếu cần
  dynamic subscribe(String destination, Function(dynamic) callback) async {
    // Bước 1: Đảm bảo đã gọi kết nối
    if (_client == null || !_client!.isActive) {
      connect();
      // [FIX LỖI] Chờ nhẹ 500ms để StompClient kịp khởi tạo Handler
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Bước 2: Thử subscribe và bắt lỗi nếu client chưa sẵn sàng
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
      // [FIX LỖI HÌNH ẢNH] Bắt lỗi "StompHandler was null"
      debugPrint(
        "⚠️ [WS] Subscribe error: $e. Attempting to force reconnect...",
      );

      _client = null; // Xóa client lỗi
      connect(); // Kết nối lại từ đầu

      // Chờ 1 giây cho chắc chắn kết nối xong
      await Future.delayed(const Duration(seconds: 1));

      // Thử subscribe lại lần 2
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
        return null; // Trả về null để App không bị Crash
      }
    }
  }
}
