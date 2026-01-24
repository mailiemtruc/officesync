// File: lib/features/notification_service/notification_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import Models & Main
import 'models/notification_model.dart';
import '../../main.dart';

// Import Data Sources & APIs
import 'package:officesync/features/hr_service/data/datasources/request_remote_data_source.dart';
import 'package:officesync/features/communication_service/data/newsfeed_api.dart';

// Import Screens (Đã import đầy đủ)
import 'package:officesync/features/chat_service/presentation/pages/chat_detail_screen.dart';
import 'package:officesync/features/communication_service/presentation/pages/post_detail_screen.dart';
import 'package:officesync/features/hr_service/presentation/pages/request_detail_page.dart';
import 'package:officesync/features/hr_service/presentation/pages/manager_request_review_page.dart';

import 'package:officesync/dashboard_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _storage = const FlutterSecureStorage();
  final _requestDataSource = RequestRemoteDataSource();

  final String _backendUrl =
      "http://10.0.2.2:8000/api/notifications/register-device";
  final String _notiBaseUrl = "http://10.0.2.2:8000/api/notifications";

  Future<void> initNotifications(int userId) async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Người dùng đã cấp quyền thông báo');
      final fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        await _registerDeviceToken(userId, fcmToken);
      }
      await _initLocalNotifications();

      _firebaseMessaging.getInitialMessage().then((message) {
        if (message != null) {
          _handleMessageClick(message);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleMessageClick(message);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("🔔 Nhận tin khi đang mở App: ${message.notification?.title}");
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });
    }
  }

  // HÀM XỬ LÝ CLICK THÔNG BÁO TỪ SYSTEM TRAY
  Future<void> _handleMessageClick(RemoteMessage message) async {
    final data = message.data;
    String? type = data['type'];
    String? idStr = data['referenceId'];
    String title = message.notification?.title ?? "Thông báo";

    print("👆 Người dùng bấm thông báo: Type=$type, ID=$idStr");

    if (type == null) return;
    int id = int.tryParse(idStr ?? "0") ?? 0;
    String? currentUserId = await _getCurrentUserId();

    switch (type) {
      case 'REQUEST':
        if (id == 0 || currentUserId == null) return;
        try {
          final requestModel = await _requestDataSource.getRequestById(
            id.toString(),
            currentUserId,
          );

          if (requestModel != null) {
            bool isMyRequest = requestModel.requesterId == currentUserId;
            if (isMyRequest) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => RequestDetailPage(request: requestModel),
                ),
              );
            } else {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) =>
                      ManagerRequestReviewPage(request: requestModel),
                ),
              );
            }
          }
        } catch (e) {
          print("❌ Lỗi điều hướng Request: $e");
        }
        break;

      case 'CHAT':
        if (id != 0) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(roomId: id, chatName: title),
            ),
          );
        }
        break;

      case 'ANNOUNCEMENT':
      case 'COMMENT':
      case 'REACTION':
        if (id != 0) {
          try {
            final post = await NewsfeedApi().getPostById(id);
            if (post != null) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
              );
            }
          } catch (e) {
            print("❌ Lỗi mở bài viết: $e");
          }
        }
        break;

      // [FIX] Điều hướng tới UserProfilePage trực tiếp
      case 'SYSTEM':
      case 'ROLE_UPDATE':
      case 'DEPARTMENT_UPDATE':
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const DashboardScreen(
              userInfo: {}, // Truyền rỗng để Dashboard tự load lại từ Storage
              initialIndex: 2, // <--- Mở ngay tab Profile (Index 2)
            ),
          ),
          (route) => false, // Xóa sạch các trang cũ để tránh lỗi chồng chéo
        );

      default:
        print("⚠️ Loại thông báo chưa hỗ trợ: $type");
    }
  }

  Future<String?> _getCurrentUserId() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final data = jsonDecode(userInfoStr);
        return data['id'].toString();
      }
      return await _storage.read(key: 'user_id');
    } catch (e) {
      return null;
    }
  }

  // CÁC HÀM KHÁC GIỮ NGUYÊN...
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

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
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
  }

  Future<List<NotificationModel>> fetchNotifications(int userId) async {
    final url = Uri.parse("$_notiBaseUrl/user/$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> rawList = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return rawList.map((e) => NotificationModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("❌ Lỗi tải thông báo: $e");
      return [];
    }
  }

  Future<void> unregisterDevice(int userId) async {
    try {
      final url = Uri.parse("$_notiBaseUrl/unregister-device");
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userId": userId}),
      );
      await _firebaseMessaging.deleteToken();
    } catch (e) {
      print("⚠️ Lỗi hủy đăng ký: $e");
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final url = Uri.parse("$_notiBaseUrl/$notificationId/read");
      await http.put(url);
    } catch (e) {
      print("⚠️ Lỗi đánh dấu đã đọc: $e");
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      final url = Uri.parse("$_notiBaseUrl/$id");
      await http.delete(url);
    } catch (e) {
      print("⚠️ Lỗi xóa: $e");
    }
  }
}
