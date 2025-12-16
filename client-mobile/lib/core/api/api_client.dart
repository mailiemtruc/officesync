import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:8080/api';

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
