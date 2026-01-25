import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/post_model.dart';
import 'models/comment_model.dart';

class NewsfeedApi {
  // 🔴 LƯU Ý: Đổi IP nếu chạy máy thật (vd: 192.168.1.x)
  static const String baseUrl = "http://10.0.2.2:8000/api/v1/newsfeed";

  final _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    // Lấy đúng key 'auth_token' mà Core Service đã lưu
    final token = await _storage.read(key: 'auth_token') ?? "";
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<List<PostModel>> fetchPosts() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse(baseUrl), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((e) => PostModel.fromJson(e)).toList();
    } else {
      throw Exception("Lỗi tải bài viết: ${response.statusCode}");
    }
  }

  // 1. ✅ THÊM HÀM UPLOAD ẢNH (Mới)
  Future<String> uploadImage(File file) async {
    try {
      print("--> Bắt đầu gửi request upload...");

      // 1. Lấy Token từ bộ nhớ (Giống các hàm khác)
      final token = await _storage.read(key: 'auth_token') ?? "";

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8000/api/files/upload'),
      );

      // 2. ✅ THÊM DÒNG NÀY: Gắn Token vào Header
      request.headers.addAll({
        "Authorization": "Bearer $token",
        // Không cần Content-Type, thư viện http tự lo vụ multipart
      });

      // 3. Add file
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // 4. Gửi request
      var streamResponse = await request.send();
      var response = await http.Response.fromStream(streamResponse);

      print("--> Status Code: ${response.statusCode}");
      print("--> Body Server trả về: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] ?? "";
      } else {
        print("❌ Upload thất bại với mã lỗi: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Upload error (Exception): $e");
    }
    return "";
  }

  // 2. ✅ SỬA HÀM CREATE POST (Thêm tham số imageUrl)
  Future<bool> createPost(
    String content,
    String imageUrl,
    String userAvatar,
  ) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode({
        "content": content,
        "imageUrl":
            imageUrl, // ✅ Truyền link ảnh thật vào đây (không để "" nữa)
        "userAvatar": userAvatar,
      }),
    );
    return response.statusCode == 200;
  }

  // 1. Lấy danh sách bình luận
  Future<List<CommentModel>> fetchComments(int postId) async {
    final headers = await _getHeaders();
    final url = "$baseUrl/$postId/comments"; // Khớp với Backend

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((e) => CommentModel.fromJson(e)).toList();
    }
    return [];
  }

  // 2. Gửi bình luận
  Future<bool> sendComment(
    int postId,
    String content,
    String userAvatar, {
    int? parentId,
  }) async {
    final headers = await _getHeaders();
    final url = "$baseUrl/$postId/comments";

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        "content": content,
        "parentId": parentId,
        "userAvatar": userAvatar, // ✅ Gửi kèm avatar
      }),
    );

    return response.statusCode == 200;
  }

  // 3. Thả Reaction (Like/Love...)
  Future<bool> reactToPost(int postId, String type) async {
    final headers = await _getHeaders();
    final url = "$baseUrl/$postId/react";

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        "type": type, // Gửi lên: "LIKE", "LOVE", "HAHA", v.v.
      }),
    );

    return response.statusCode == 200;
  }

  // 4. Gọi API đếm view
  Future<void> viewPost(int postId) async {
    final headers = await _getHeaders();
    final url = "$baseUrl/$postId/view";
    // Gọi fire-and-forget (không cần chờ kết quả trả về)
    http.post(Uri.parse(url), headers: headers);
  }

  // ✅ [MỚI] Gọi Backend cập nhật avatar ngay lập tức
  Future<void> syncUserAvatar(String newAvatarUrl) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse("$baseUrl/sync-user"), // Gọi vào API vừa tạo
        headers: headers,
        body: jsonEncode({"avatarUrl": newAvatarUrl}),
      );

      if (response.statusCode == 200) {
        print("--> Communication Service đã cập nhật Avatar mới!");
      }
    } catch (e) {
      print("Lỗi sync avatar: $e");
    }
  }

  Future<PostModel?> getPostById(int postId) async {
    try {
      final headers = await _getHeaders();
      final url = "$baseUrl/$postId";
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return PostModel.fromJson(body);
      }
    } catch (e) {
      print("Lỗi lấy bài viết: $e");
    }
    return null;
  }
}
