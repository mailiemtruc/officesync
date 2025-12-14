import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // ⚠️ CẤU HÌNH IP:
  // - Android Emulator: 'http://10.0.2.2:8080/api'
  // - Máy thật / iOS: Dùng IP LAN của máy tính (VD: 'http://192.168.1.10:8080/api')
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60), // Chờ 60s (Cho gửi mail)
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Khởi tạo Storage 1 lần
  final _storage = const FlutterSecureStorage();

  // --- HÀM LẤY HEADER KÈM TOKEN ---
  Future<Options> _getOptions() async {
    String? token = await _storage.read(key: 'auth_token');
    return Options(
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  // --- 1. POST (Đăng nhập, Đăng ký, Gửi OTP...) ---
  Future<Response> post(String path, {dynamic data}) async {
    try {
      final options = await _getOptions();
      return await _dio.post(path, data: data, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- 2. GET (Lấy thông tin User, Danh sách...) ---
  Future<Response> get(String path) async {
    try {
      final options = await _getOptions();
      return await _dio.get(path, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- 3. PUT (Cập nhật Profile, Đổi mật khẩu...) ---
  Future<Response> put(String path, {dynamic data}) async {
    try {
      final options = await _getOptions();
      return await _dio.put(path, data: data, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- 4. DELETE (Xóa dữ liệu) ---
  Future<Response> delete(String path) async {
    try {
      final options = await _getOptions();
      return await _dio.delete(path, options: options);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // --- HELPER: XỬ LÝ LỖI ĐẸP HƠN ---
  String _handleError(DioException e) {
    if (e.response != null) {
      // TH1: Server trả về chuỗi lỗi trực tiếp (VD: "Invalid OTP")
      if (e.response!.data is String) {
        return e.response!.data.toString();
      }
      // TH2: Server trả về JSON (VD: {"message": "User exists", "status": 400})
      if (e.response!.data is Map) {
        final Map data = e.response!.data;
        if (data.containsKey('message')) return data['message'];
        if (data.containsKey('error')) return data['error'];
      }
      return "Server Error: ${e.response!.statusCode}";
    }
    // TH3: Không có phản hồi (Mất mạng, Server sập)
    return "Connection failed. Please check your internet or server.";
  }
}
