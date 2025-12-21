import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/newsfeed_api.dart';
import '../../data/models/post_model.dart';
import '../../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart'; // Lát nữa tạo file này
import '../../../../core/config/app_colors.dart';

class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({super.key});

  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  final _api = NewsfeedApi();
  late Future<List<PostModel>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPosts();
  }

  void _refreshPosts() {
    setState(() {
      _postsFuture = _api.fetchPosts();
    });
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
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black, // Avatar đen giống design
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostScreen(
                            onPost: (content, image) async {
                              await _api.createPost(content);
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
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

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
                        onTap: () {
                          // Bấm vào thẻ bài viết -> Sang màn hình chi tiết
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PostDetailScreen(post: posts[index]),
                            ),
                          );
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
