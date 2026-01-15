import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/newsfeed_api.dart';
import '../../data/models/post_model.dart';
import '../../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart'; // Lát nữa tạo file này
import '../../../../core/config/app_colors.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({super.key});

  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  final _api = NewsfeedApi();
  final _storage = const FlutterSecureStorage();
  late Future<List<PostModel>> _postsFuture;
  String _currentAvatar = ""; // Biến lưu avatar để hiển thị

  @override
  void initState() {
    super.initState();
    _loadMyAvatar();
    _refreshPosts();
  }

  // Hàm load avatar từ bộ nhớ máy
  Future<void> _loadMyAvatar() async {
    String avatar = await _getMyAvatar();
    if (mounted) {
      setState(() {
        _currentAvatar = avatar;
      });
    }
  }

  void _refreshPosts() {
    setState(() {
      _postsFuture = _api.fetchPosts();
    });
  }

  // ✅ THÊM HÀM LẤY AVATAR TỪ CACHE
  Future<String> _getMyAvatar() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final data = jsonDecode(userInfoStr);
        return data['avatarUrl'] ?? "";
      }
    } catch (e) {
      print(e);
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      // AppBar đơn giản, có nút Back về Dashboard
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Internal Newsfeed",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              PhosphorIconsRegular.bell,
              color: AppColors.primary,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Input Bar "What's On Your Mind?" (Giống Figma)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: _currentAvatar.isNotEmpty
                      ? NetworkImage(_currentAvatar)
                      : null,
                  child: _currentAvatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostScreen(
                            myAvatarUrl: _currentAvatar,
                            onPost: (content, imageFile) async {
                              String imageUrl = "";
                              // 1. Nếu người dùng có chọn ảnh -> Upload lên Server trước
                              if (imageFile != null) {
                                imageUrl = await _api.uploadImage(imageFile);
                              }

                              // 2. Gọi API tạo bài viết với link ảnh vừa có
                              await _api.createPost(
                                content,
                                imageUrl,
                                _currentAvatar,
                              );
                              _refreshPosts();
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Màu xám nhạt
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        "What's On Your Mind?",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Danh sách bài viết
          Expanded(
            child: FutureBuilder<List<PostModel>>(
              future: _postsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // ✅ SỬA LOGIC Ở ĐÂY
                // Nếu snapshot có data, ta gán vào 1 biến list tạm để có thể chỉnh sửa
                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return const Center(child: Text("No news yet."));
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshPosts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                        post: posts[index],
                        onTap: () async {
                          // ✅ LOGIC ĐỒNG BỘ: Chờ kết quả trả về từ trang chi tiết
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PostDetailScreen(post: posts[index]),
                            ),
                          );
                          // ✅ Nếu có dữ liệu trả về -> Cập nhật ngay tại chỗ
                          if (result != null && result is Map) {
                            setState(() {
                              // Cập nhật lại đúng bài viết tại vị trí index
                              posts[index] = posts[index].copyWith(
                                reactionCount: result['reactionCount'],
                                commentCount: result['commentCount'],
                                myReaction: result['isLiked'] == true
                                    ? "LOVE"
                                    : null,
                                clearReaction: result['isLiked'] == false,
                              );
                            });
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
