import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/models/post_model.dart';
import '../../../../core/config/app_colors.dart';

class PostDetailScreen extends StatelessWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Post Details",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Bài viết (Avatar + Tên)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(post.authorAvatar),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              post.createdAt,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Nội dung Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Ảnh to (Full width)
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                    Image.network(
                      post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  else
                    // Placeholder ảnh giống design
                    Container(
                      width: double.infinity,
                      height: 250,
                      color: const Color(0xFFE2E8F0),
                      child: const Center(
                        child: Icon(
                          PhosphorIconsBold.camera,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                  // 4. Like & Comment Count
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsRegular.heart, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "${post.reactionCount}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 20),
                        const Icon(PhosphorIconsRegular.chatCircle, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "${post.commentCount}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // 5. Danh sách bình luận (Comment List)
                  // (Đây là dữ liệu giả mẫu theo design, sau này thay bằng API thật)
                  _buildCommentItem(
                    "Nguyen Binh",
                    "2h",
                    "Very Useful Post!",
                    true,
                  ),
                  _buildCommentItem(
                    "Trung Dai",
                    "2h",
                    "Very Useful Post Qq!",
                    true,
                  ),
                ],
              ),
            ),
          ),

          // 6. Thanh nhập bình luận (Bottom Input)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: "Write A Comment...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  PhosphorIconsRegular.paperPlaneRight,
                  color: AppColors.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    String name,
    String time,
    String content,
    bool isLiked,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.black, // Avatar đen giả định
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      "Reply",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLiked)
                      const Icon(
                        PhosphorIconsRegular.thumbsUp,
                        size: 14,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
