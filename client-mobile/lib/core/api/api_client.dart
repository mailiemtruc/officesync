import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  // --- CORE & NOTE SERVICE METHODS (ĐÃ SỬA) ---

  // [SỬA] Thêm tham số queryParameters và options
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options, // <--- Nhận options từ bên ngoài
  }) async {
    try {
      // 1. Lấy Options mặc định (có Token)
      final baseOptions = await _getOptions();

      // 2. Nếu có options bên ngoài truyền vào (ví dụ Header riêng), thì merge vào baseOptions
      if (options != null && options.headers != null) {
        baseOptions.headers?.addAll(options.headers!);
      }

      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: baseOptions, // Dùng options đã merge
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // [SỬA] Thêm tham số queryParameters và options
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options, // <--- Nhận options từ bên ngoài
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

  // [SỬA] Thêm tham số options
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

  // [SỬA] Thêm tham số options
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

  // --- ERROR HANDLING ---
  String _handleError(DioException e) {
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
}
