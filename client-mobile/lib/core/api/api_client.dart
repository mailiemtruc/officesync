import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // Import UI
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../main.dart'; // Để lấy navigatorKey
import '../services/security_service.dart';
import '../services/websocket_service.dart';
import '../utils/custom_snackbar.dart';

class ApiClient {
  // Base URL cho Core Service (Logic chính)
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // Base URL cho Storage Service (Lưu file)
  static const String storageUrl = 'http://10.0.2.2:8090/api';

  // Base URL cho Note Service (Port 8082)
  static const String noteUrl = 'http://10.0.2.2:8082/api';

  //Base URL cho Task Service (Port 8086)
  static const String taskUrl = 'http://10.0.2.2:8086/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final _storage = const FlutterSecureStorage();

  Future<Options> _getOptions() async {
    String? token = await _storage.read(key: 'auth_token');
    String? userInfoStr = await _storage.read(key: 'user_info');
    String? userId;

    if (userInfoStr != null) {
      try {
        final userData = jsonDecode(userInfoStr);
        userId = userData['id'].toString();
      } catch (e) {
        print("Lỗi đọc user info: $e");
      }
    }

    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId,
      },
    );
  }

  // --- CORE & NOTE SERVICE METHODS ---

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final baseOptions = await _getOptions();

      if (options != null && options.headers != null) {
        baseOptions.headers?.addAll(options.headers!);
      }

      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: baseOptions,
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final baseOptions = await _getOptions();

      if (options != null && options.headers != null) {
        baseOptions.headers?.addAll(options.headers!);
      }

      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: baseOptions,
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Response> put(String path, {dynamic data, Options? options}) async {
    try {
      final baseOptions = await _getOptions();

      if (options != null && options.headers != null) {
        baseOptions.headers?.addAll(options.headers!);
      }

      return await _dio.put(path, data: data, options: baseOptions);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Response> delete(String path, {Options? options}) async {
    try {
      final baseOptions = await _getOptions();

      if (options != null && options.headers != null) {
        baseOptions.headers?.addAll(options.headers!);
      }

      return await _dio.delete(path, options: baseOptions);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- STORAGE SERVICE METHODS ---
  Future<String> uploadImageToStorage(String filePath) async {
    try {
      final storageDio = Dio(
        BaseOptions(
          baseUrl: storageUrl,
          connectTimeout: const Duration(seconds: 60),
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await storageDio.post('/files/upload', data: formData);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data.containsKey('url')) {
          return data['url'].toString();
        }
      }

      throw Exception("Invalid response from Storage Service");
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- ERROR HANDLING (ĐÃ SỬA ĐỂ CHẶN THIẾT BỊ CŨ) ---
  String _handleError(DioException e) {
    // Bắt lỗi 401 hoặc 403 từ Backend (Token Version không khớp)
    if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      print("🚨 Hard Kick Triggered: Token cũ hoặc không hợp lệ. Logout ngay!");

      // Gọi hàm đá người dùng ra
      _forceLogout();

      return "Phiên đăng nhập đã hết hạn do tài khoản được dùng ở nơi khác.";
    }

    if (e.response != null) {
      if (e.response!.data is String) {
        return e.response!.data.toString();
      }

      if (e.response!.data is Map) {
        final Map data = e.response!.data;
        if (data.containsKey('message')) return data['message'];
        if (data.containsKey('error')) return data['error'];
      }
      return "Server Error: ${e.response!.statusCode}";
    }

    return "Connection failed. Please check your internet or server.";
  }

  // Hàm cưỡng chế đăng xuất (Giống SecurityService)
  void _forceLogout() async {
    try {
      // 1. Xóa sạch Token lưu trong máy
      await _storage.deleteAll();

      // 2. Ngắt kết nối Socket (để không nhận tin rác nữa)
      SecurityService().disconnect();
      WebSocketService().disconnect();

      // 3. Chuyển hướng về màn hình Login
      // Sử dụng navigatorKey toàn cục từ main.dart để chuyển trang dù không có context ở đây
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );

        // Hiện thông báo (Tuỳ chọn)
        CustomSnackBar.showGlobal(
          title: "Logged Out",
          message: "Your account is already logged in on another device.",
          isError: true,
        );
      }
    } catch (e) {
      print("Error during force logout: $e");
    }
  }
}
