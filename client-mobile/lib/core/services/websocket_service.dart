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

  // [THAY ĐỔI LỚN 1] Dùng Map để lưu nhiều kết nối cùng lúc
  // Key: URL (ví dụ ws://...:8080), Value: StompClient tương ứng
  final Map<String, StompClient> _clients = {};

  // Lưu URL gần nhất để làm mặc định cho các màn hình cũ không truyền forceUrl
  String? _lastConnectedUrl;

  // Kiểm tra xem 1 URL cụ thể có đang kết nối không
  bool isConnected(String url) => _clients[url]?.connected ?? false;

  // 1. Hàm kết nối: Hỗ trợ đa kết nối
  void connect(String url) {
    // Case 1: Nếu URL này ĐANG kết nối rồi -> Cập nhật mặc định và thoát
    if (_clients.containsKey(url) && _clients[url]!.connected) {
      // debugPrint("ℹ️ [WS] Already connected to $url");
      _lastConnectedUrl = url;
      return;
    }

    // Case 2: Nếu đang có client cũ tại URL này mà bị lỗi/ngắt -> Clean trước
    if (_clients.containsKey(url)) {
      debugPrint("🔄 [WS] Refreshing connection to $url");
      _clients[url]!.deactivate();
    }

    debugPrint("🚀 [WS] Connecting to $url ...");

    final client = StompClient(
      config: StompConfig(
        url: url,
        onConnect: (StompFrame frame) {
          debugPrint("✅ [WS] Connected to $url");
        },
        onWebSocketError: (dynamic error) =>
            debugPrint("❌ [WS] Error $url: $error"),
        onDisconnect: (f) => debugPrint("🔌 [WS] Disconnected $url"),
        // Tự động kết nối lại sau 5s nếu mất mạng
        connectionTimeout: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    client.activate();

    // Lưu vào Map và set làm URL mặc định
    _clients[url] = client;
    _lastConnectedUrl = url;
  }

  // 2. Ngắt kết nối (Cụ thể hoặc Tất cả)
  void disconnect({String? url}) {
    if (url != null) {
      // Ngắt 1 kết nối cụ thể (Ví dụ khi rời màn hình Chấm công)
      _clients[url]?.deactivate();
      _clients.remove(url);
      if (_lastConnectedUrl == url) _lastConnectedUrl = null;
      debugPrint("🛑 [WS] Deactivated connection: $url");
    } else {
      // Ngắt HẾT (Dùng khi Logout)
      _clients.forEach((key, client) => client.deactivate());
      _clients.clear();
      _lastConnectedUrl = null;
      debugPrint("🛑 [WS] Deactivated ALL connections");
    }
  }

  // 3. Hàm Subscribe thông minh (Nâng cấp)
  // [THAY ĐỔI LỚN 2] Thêm tham số `forceUrl`
  dynamic subscribe(
    String destination,
    Function(dynamic) callback, {
    String? forceUrl,
  }) async {
    // Xác định URL cần dùng:
    // - Nếu truyền forceUrl (Dùng cho SecurityService) -> Dùng nó
    // - Nếu không (Dùng cho UI cũ) -> Dùng URL gần nhất
    String? targetUrl = forceUrl ?? _lastConnectedUrl;

    // Bước 1: Kiểm tra URL
    if (targetUrl == null) {
      debugPrint("⚠️ [WS] Chưa có kết nối nào. Gọi connect(url) trước!");
      return null;
    }

    // Bước 2: Đảm bảo kết nối tới URL đích tồn tại
    if (!_clients.containsKey(targetUrl) || !_clients[targetUrl]!.isActive) {
      connect(targetUrl);
      // Chờ nhẹ 500ms
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Bước 3: Thử subscribe trên đúng Client của URL đó
    try {
      final client = _clients[targetUrl];
      return client?.subscribe(
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
      // Logic Retry thông minh (đã sửa để support đa URL)
      debugPrint("⚠️ [WS] Subscribe error on $targetUrl: $e. Retrying...");

      // Reconnect đúng URL bị lỗi
      connect(targetUrl);
      await Future.delayed(const Duration(seconds: 1));

      try {
        return _clients[targetUrl]?.subscribe(
          destination: destination,
          callback: (StompFrame frame) {
            // ... (callback logic như trên) ...
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
        debugPrint("❌ [WS] Retry failed on $targetUrl: $e2");
        return null;
      }
    }
  }
}
