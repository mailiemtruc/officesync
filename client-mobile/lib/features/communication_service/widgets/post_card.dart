import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/post_model.dart';
import '../../../../core/config/app_colors.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Để sau này bấm vào xem chi tiết
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20), // Bo góc 20
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Avatar + Name + Time)
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: NetworkImage(post.authorAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                        post.createdAt, // Bạn có thể format lại ví dụ: "1 Day"
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Content Text
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),
              ),

            // 3. Image (Nếu có) - Hiển thị to như design
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF1F5F9),
                  image: DecorationImage(
                    image: NetworkImage(post.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            // Placeholder hình cái máy ảnh nếu không có ảnh (cho giống design Figma của bạn)
            else
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF1F5F9),
                ),
                child: const Center(
                  child: Icon(
                    PhosphorIconsBold.camera,
                    size: 48,
                    color: Colors.black12,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // 4. Footer (Like / Comment)
            Row(
              children: [
                _buildAction(
                  post.myReaction != null
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
                  "${post.reactionCount}",
                  post.myReaction != null ? Colors.red : Colors.black87,
                ),
                const SizedBox(width: 20),
                _buildAction(
                  PhosphorIconsRegular.chatCircle,
                  "${post.commentCount}",
                  Colors.black87,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 6),
        Text(
          count,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}
