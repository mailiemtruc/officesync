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

  // [MỚI] Biến lưu URL hiện tại để phục vụ việc reconnect
  String? _currentUrl;

  bool get isConnected => _client?.connected ?? false;

  // 1. Hàm kết nối: [SỬA] Nhận tham số URL động
  void connect(String url) {
    // Case 1: Nếu client đang kết nối TỐT và ĐÚNG URL này -> Không làm gì cả
    if (_client != null && _client!.connected && _currentUrl == url) {
      // debugPrint("ℹ️ [WS] Already connected to $url");
      return;
    }

    // Case 2: Nếu đang có kết nối tới URL khác -> Ngắt cái cũ
    if (_client != null) {
      debugPrint("🔄 [WS] Switching connection from $_currentUrl to $url");
      _client!.deactivate();
    }

    // Cập nhật URL hiện tại
    _currentUrl = url;

    _client = StompClient(
      config: StompConfig(
        url: url,
        onConnect: (StompFrame frame) {
          debugPrint("✅ [WS] Connected to $url");
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
    _currentUrl = null; // Reset URL
    debugPrint("🛑 [WS] Deactivated Global");
  }

  // 3. Hàm đăng ký nhận tin (Giữ nguyên logic FIX LỖI CRASH của bạn)
  dynamic subscribe(String destination, Function(dynamic) callback) async {
    // Bước 1: Kiểm tra URL
    if (_currentUrl == null) {
      debugPrint("⚠️ [WS] Chưa có URL. Vui lòng gọi connect(url) trước!");
      return null;
    }

    // Bước 2: Đảm bảo đã gọi kết nối
    if (_client == null || !_client!.isActive) {
      connect(_currentUrl!); // Sử dụng URL đã lưu
      // [FIX LỖI] Chờ nhẹ 500ms để StompClient kịp khởi tạo Handler
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Bước 3: Thử subscribe và bắt lỗi
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
      // [FIX LỖI HÌNH ẢNH] Logic Retry thông minh của bạn
      debugPrint(
        "⚠️ [WS] Subscribe error: $e. Attempting to force reconnect to $_currentUrl...",
      );

      _client = null; // Xóa client lỗi

      // [SỬA] Reconnect lại vào đúng URL hiện tại
      if (_currentUrl != null) {
        connect(_currentUrl!);
      }

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
