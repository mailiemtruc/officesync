import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // ⚠️ QUAN TRỌNG:
  // - Máy ảo Android: dùng 10.0.2.2
  // - Máy thật / iOS: dùng IP LAN của máy tính (VD: http://192.168.1.5:8089...)
  final String _backendUrl =
      "http://10.0.2.2:8089/api/notifications/register-device";

  Future<void> initNotifications(int userId) async {
    // 1. Xin quyền
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Người dùng đã cấp quyền thông báo');

      // 2. Lấy Token
      final fcmToken = await _firebaseMessaging.getToken();
      print("👉 FCM Token: $fcmToken");

      if (fcmToken != null) {
        await _registerDeviceToken(userId, fcmToken);
      }

      // 3. Cấu hình Local Notification (để hiện thông báo khi App đang mở)
      await _initLocalNotifications();

      // 4. Lắng nghe khi App đang mở (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("🔔 Nhận tin khi đang mở App: ${message.notification?.title}");

        // Hiện thông báo ngay lập tức
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });
    } else {
      print('❌ Người dùng từ chối quyền thông báo');
    }
  }

  // Cấu hình hiển thị thông báo nội bộ
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);
  }

  // Hàm hiển thị thông báo dạng Banner
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // Id channel
      'High Importance Notifications', // Tên channel
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
    );
  }

  Future<void> _registerDeviceToken(int userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userId": userId, "token": token}),
      );
      if (response.statusCode == 200) {
        print("✅ Backend đã lưu Token thành công!");
      }
    } catch (e) {
      print("❌ Lỗi kết nối Backend: $e");
    }
  } // 1. Hàm gọi API lấy danh sách thông báo

  Future<List<NotificationModel>> fetchNotifications(int userId) async {
    final url = Uri.parse(
      "http://10.0.2.2:8089/api/notifications/user/$userId",
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decode JSON
        final List<dynamic> rawList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        // 3. Map từ JSON sang Model
        return rawList.map((e) => NotificationModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("❌ Lỗi tải thông báo: $e");
      return [];
    }
  }

  // 2. Hàm hủy đăng ký (Dùng cho nút Logout)
  Future<void> unregisterDevice(int userId) async {
    try {
      final url = Uri.parse(
        "http://10.0.2.2:8089/api/notifications/unregister-device",
      );
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userId": userId}),
      );

      // Xóa token phía Client luôn cho sạch
      await _firebaseMessaging.deleteToken();
      print("👋 Đã hủy đăng ký thiết bị (Logout thành công)");
    } catch (e) {
      print("⚠️ Lỗi hủy đăng ký: $e");
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      // Gọi API báo Server là đã đọc tin này
      final url = Uri.parse(
        "http://10.0.2.2:8089/api/notifications/$notificationId/read",
      );

      // Gửi request PUT (không cần body)
      await http.put(url);
    } catch (e) {
      print("⚠️ Lỗi đánh dấu đã đọc: $e");
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      final url = Uri.parse("http://10.0.2.2:8089/api/notifications/$id");
      await http.delete(url);
    } catch (e) {
      print("⚠️ Lỗi xóa: $e");
    }
  }
}
