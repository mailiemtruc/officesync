import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/newsfeed_api.dart';
import '../../data/models/post_model.dart';
import '../../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import '../../../../core/config/app_colors.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/socket_service.dart'; // Import SocketService

class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({super.key});

  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  final _api = NewsfeedApi();
  final _storage = const FlutterSecureStorage();

  // 🔴 THAY ĐỔI 1: Không dùng Future, dùng List biến
  List<PostModel> _posts = [];
  bool _isLoading = true;
  String _currentAvatar = "";

  @override
  void initState() {
    super.initState();
    _loadMyAvatar();
    _loadPostsInitial(); // Load lần đầu
    _connectSocket(); // Kết nối Socket
  }

  // Hàm load dữ liệu từ API lần đầu
  void _loadPostsInitial() async {
    try {
      final data = await _api.fetchPosts();
      if (mounted) {
        setState(() {
          _posts = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi tải bài viết: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm refresh (khi kéo xuống)
  Future<void> _refreshPosts() async {
    final data = await _api.fetchPosts();
    if (mounted) {
      setState(() {
        _posts = data;
      });
    }
  }

  Future<void> _loadMyAvatar() async {
    String avatar = await _getMyAvatar();
    if (mounted) {
      setState(() {
        _currentAvatar = avatar;
      });
    }
  }

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

  // 🔴 THAY ĐỔI 2: Logic Socket Real-time
  void _connectSocket() async {
    // 1. Lấy companyId từ bộ nhớ (giữ nguyên logic cũ)
    String? userInfoStr = await _storage.read(key: 'user_info');
    int myCompanyId = 1;

    if (userInfoStr != null) {
      final data = jsonDecode(userInfoStr);
      myCompanyId = int.tryParse(data['companyId'].toString()) ?? 1;
    }

    print("👉 [Socket] Đang lắng nghe Company ID: $myCompanyId");

    SocketService().connect(
      onConnected: () {
        // 2. Subscribe kênh công ty
        SocketService().subscribeToCompany(myCompanyId, (data) {
          print("🔔 SOCKET DATA: $data");

          // ✅ TRƯỜNG HỢP 1: UPDATE SỐ LƯỢNG (Tim/Comment)
          // Backend gửi: {type: "UPDATE_COUNTS", postId: 1, reactionCount: 5, ...}
          if (data['type'] == 'UPDATE_COUNTS') {
            int postId = data['postId'];
            int rCount = data['reactionCount'];
            int cCount = data['commentCount'];

            // Tìm bài viết trong list đang hiển thị để update số
            int index = _posts.indexWhere((p) => p.id == postId);
            if (index != -1) {
              if (mounted) {
                setState(() {
                  // Copy bài viết cũ và thay số liệu mới vào
                  _posts[index] = _posts[index].copyWith(
                    reactionCount: rCount,
                    commentCount: cCount,
                  );
                });
              }
            }
          }
          // ✅ TRƯỜNG HỢP 2: CÓ BÀI VIẾT MỚI
          // Backend gửi: {id: 10, content: "Hello", ...}
          else {
            try {
              PostModel newPost = PostModel.fromJson(data);
              if (mounted) {
                setState(() {
                  _posts.insert(0, newPost);
                });

                // 👇👇👇 THAY TOÀN BỘ ĐOẠN ScaffoldMessenger CŨ BẰNG ĐOẠN NÀY 👇👇👇
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981), // Màu xanh Emerald đẹp
                        borderRadius: BorderRadius.circular(16), // Bo tròn góc
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon Check tròn
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Nội dung chữ
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "New Post",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "From ${newPost.authorName}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    behavior: SnackBarBehavior.floating, // Nổi lên trên
                    backgroundColor:
                        Colors.transparent, // Nền trong suốt để hiện bo góc
                    elevation: 0, // Tắt bóng mặc định
                    margin: const EdgeInsets.all(20), // Cách lề màn hình
                    duration: const Duration(seconds: 3),
                  ),
                );
                // 👆👆👆 KẾT THÚC ĐOẠN CODE MỚI 👆👆👆
              }
            } catch (e) {
              print("Lỗi parse bài viết socket: $e");
            }
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
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
      ),
      body: Column(
        children: [
          // 1. Input Bar
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
                              // Logic đăng bài giữ nguyên
                              String imageUrl = "";
                              if (imageFile != null) {
                                imageUrl = await _api.uploadImage(imageFile);
                              }
                              await _api.createPost(
                                content,
                                imageUrl,
                                _currentAvatar,
                              );

                              // Không cần gọi _refreshPosts() ở đây nữa
                              // vì Socket sẽ tự bắn tin về để cập nhật!
                              // Nhưng gọi cũng không sao, cho chắc ăn.
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
                        color: const Color(0xFFF1F5F9),
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

          // 🔴 THAY ĐỔI 3: Dùng ListView trực tiếp, bỏ FutureBuilder
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                ? const Center(child: Text("No news yet."))
                : RefreshIndicator(
                    onRefresh: _refreshPosts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        return PostCard(
                          key: ValueKey(_posts[index].id),
                          post: _posts[index],
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PostDetailScreen(post: _posts[index]),
                              ),
                            );
                            if (result != null && result is Map) {
                              setState(() {
                                _posts[index] = _posts[index].copyWith(
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
                  ),
          ),
        ],
      ),
    );
  }
}
