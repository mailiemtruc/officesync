import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'websocket_service.dart';
import '../../main.dart'; // Import để lấy navigatorKey
import '../utils/custom_snackbar.dart'; // Import CustomSnackBar

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _storage = const FlutterSecureStorage();
  bool _isListening = false;

  // URL của Core Service (Port 8080)
  final String _coreUrl = 'ws://10.0.2.2:8080/ws-core';

  // Hàm kích hoạt bảo mật
  void startListening(int userId, int? companyId) {
    if (_isListening) return;

    final wsService = WebSocketService();

    // 1. Kết nối tới Core Service (8080)
    wsService.connect(_coreUrl);
    print("🛡️ Security Service: Connecting to $_coreUrl...");
    _isListening = true;

    // 2. Lắng nghe các sự kiện bảo mật CÁ NHÂN (Khoá nick, Login nơi khác)
    wsService.subscribe(
      '/topic/user/$userId/security',
      (data) {
        if (data is Map) {
          // --- CASE 1: Bị Admin khoá tài khoản ---
          if (data['type'] == 'ACCOUNT_LOCKED') {
            _triggerGlobalLock(data['message'] ?? "Tài khoản đã bị khoá.");
          }

          // --- CASE 2: [MỚI] Có thiết bị khác đăng nhập ---
          if (data['type'] == 'LOGIN_CONFLICT') {
            _triggerGlobalLock(
              data['message'] ?? "Tài khoản đã đăng nhập ở nơi khác.",
            );
          }
        }
      },
      forceUrl: _coreUrl, // QUAN TRỌNG: Chỉ nghe từ cổng 8080
    );

    // 3. Lắng nghe sự kiện KHOÁ CÔNG TY (Nếu user thuộc công ty nào đó)
    if (companyId != null && companyId > 0) {
      wsService.subscribe('/topic/company/$companyId/security', (data) {
        if (data is Map && data['type'] == 'COMPANY_LOCKED') {
          _triggerGlobalLock(data['message'] ?? "Công ty bị tạm dừng.");
        }
      }, forceUrl: _coreUrl);
    }
  }

  // 🔴 [MỚI] Hàm ngắt kết nối chủ động (Gọi khi Logout)
  void disconnect() {
    if (_isListening) {
      print("🛡️ Security Service: Stopping...");
      // Ngắt kết nối socket cụ thể của Core Service
      WebSocketService().disconnect(url: _coreUrl);
      // Reset cờ trạng thái để lần sau đăng nhập có thể kết nối lại
      _isListening = false;
    }
  }

  // Hàm Logout cưỡng chế
  void _triggerGlobalLock(String message) {
    print("🔒 SECURITY ALERT: $message");

    // A. Hiện thông báo ĐỎ đè lên tất cả màn hình
    CustomSnackBar.showGlobal(
      title: "ACCESS DENIED",
      message: message,
      isError: true, // Kích hoạt màu đỏ và icon cảnh báo
    );

    // B. Đếm ngược 5 giây rồi đá ra ngoài
    Timer(const Duration(seconds: 5), () async {
      // 1. Xóa Token
      await _storage.deleteAll();

      // 2. Gọi hàm disconnect mới để reset trạng thái
      disconnect();

      // Ngắt toàn bộ các socket khác (như HR Service, Chat...) để sạch sẽ
      WebSocketService().disconnect();

      // 3. Chuyển hướng về Login (xoá sạch history cũ)
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }
}
