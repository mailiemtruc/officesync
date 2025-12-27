import 'dart:convert'; // [MỚI] Thêm import này để dùng jsonDecode
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Base URL cho Core Service (Logic chính)
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // Base URL cho Storage Service (Lưu file)
  static const String storageUrl = 'http://10.0.2.2:8090/api';

  // Base URL cho Note Service (Port 8082)
  static const String noteUrl = 'http://10.0.2.2:8082/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  final _storage = const FlutterSecureStorage();

  // [ĐÃ SỬA] Hàm này giờ sẽ lấy thêm User ID để gửi Header
  Future<Options> _getOptions() async {
    String? token = await _storage.read(key: 'auth_token');

    // Đọc thông tin user từ bộ nhớ (đã lưu lúc Login)
    String? userInfoStr = await _storage.read(key: 'user_info');
    String? userId;

    if (userInfoStr != null) {
      try {
        final userData = jsonDecode(userInfoStr);
        // Lấy ID ra để gửi cho Backend (Lưu ý: Backend nhận Long nên mình gửi String số)
        userId = userData['id'].toString();
      } catch (e) {
        print("Lỗi đọc user info: $e");
      }
    }

    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',

        // [QUAN TRỌNG] Gửi kèm ID để Note Service (và các service khác) biết ai đang gọi
        if (userId != null) 'X-User-Id': userId,
      },
    );
  }

  // --- CORE & NOTE SERVICE METHODS ---

  Future<Response> post(String path, {dynamic data}) async {
    try {
      final options = await _getOptions();
      // Dio thông minh: Nếu 'path' bắt đầu bằng http (ví dụ noteUrl),
      // nó sẽ bỏ qua baseUrl mặc định (8080) và dùng url đầy đủ đó.
      return await _dio.post(path, data: data, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Response> get(String path) async {
    try {
      final options = await _getOptions();
      return await _dio.get(path, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      final options = await _getOptions();
      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Response> delete(String path) async {
    try {
      final options = await _getOptions();
      return await _dio.delete(path, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- STORAGE SERVICE METHODS (Port 8090) ---
  // (Phần này giữ nguyên không đổi)

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
