import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Base URL cho Core Service (Logic chính)
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // Base URL cho Storage Service (Lưu file)
  static const String storageUrl = 'http://10.0.2.2:8090/api';

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
    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  // --- CORE SERVICE METHODS (Port 8080) ---

  Future<Response> post(String path, {dynamic data}) async {
    try {
      final options = await _getOptions();
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

  /// Hàm upload ảnh sang Storage Service
  /// Trả về: URL của ảnh (String) để sau đó gửi sang Core Service
  Future<String> uploadImageToStorage(String filePath) async {
    try {
      // 1. Tạo instance Dio riêng cho Storage Service (Vì khác Port 8090)
      final storageDio = Dio(
        BaseOptions(
          baseUrl: storageUrl,
          connectTimeout: const Duration(seconds: 60),
          headers: {
            // Upload file cần content-type này, Dio sẽ tự xử lý boundary
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      // 2. Chuẩn bị dữ liệu FormData
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        // Key "file" phải khớp với @RequestParam("file") trong FileUploadController java
        "file": await MultipartFile.fromFile(filePath, filename: fileName),
      });

      // 3. Gọi API: POST /api/files/upload
      final response = await storageDio.post('/files/upload', data: formData);

      // 4. Xử lý kết quả trả về
      // Backend trả về: { "url": "http://10.0.2.2:8090/img/..." }
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map && data.containsKey('url')) {
          return data['url'].toString();
        }
      }

      throw Exception("Invalid response from Storage Service");
    } on DioException catch (e) {
      // Tận dụng hàm xử lý lỗi có sẵn
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
