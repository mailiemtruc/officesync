import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'models/post_model.dart';
import 'models/comment_model.dart';

class NewsfeedApi {
  // 🔴 LƯU Ý: Đổi IP nếu chạy máy thật (vd: 192.168.1.x)
  static const String baseUrl = "http://10.0.2.2:8088/api/v1/newsfeed";

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

  Future<bool> createPost(String content) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode({"content": content, "imageUrl": ""}),
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
  Future<bool> sendComment(int postId, String content, {int? parentId}) async {
    final headers = await _getHeaders();
    final url = "$baseUrl/$postId/comments";

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        "content": content,
        "parentId": null, // Mặc định là null nếu không reply
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
}
