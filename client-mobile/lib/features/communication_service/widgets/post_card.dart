import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/post_model.dart';
import '../data/newsfeed_api.dart'; // Import API để gọi thả tim

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  // Biến trạng thái local để phản hồi ngay lập tức (Optimistic UI)
  late bool _isLiked;
  late int _reactionCount;
  final _api = NewsfeedApi();

  @override
  void initState() {
    super.initState();
    // Khởi tạo trạng thái từ dữ liệu bài viết
    _isLiked =
        widget.post.myReaction != null; // Nếu khác null tức là đã thả reaction
    _reactionCount = widget.post.reactionCount;
  }

  // Hàm xử lý khi bấm Like
  void _handleLike() {
    // 1. Lưu lại trạng thái cũ để lỡ lỗi thì revert
    final previousState = _isLiked;
    final previousCount = _reactionCount;

    // 2. Cập nhật giao diện NGAY LẬP TỨC (Optimistic Update)
    setState(() {
      if (_isLiked) {
        // Nếu đang Like -> Bỏ Like
        _isLiked = false;
        _reactionCount--;
      } else {
        // Nếu chưa Like -> Thả Like (Mặc định là 'LIKE' hoặc 'LOVE')
        _isLiked = true;
        _reactionCount++;
      }
    });

    // 3. Gọi API ngầm bên dưới
    // Nếu đang like -> gửi "LIKE" (hoặc "LOVE" tùy bạn chọn icon)
    // Server của bạn đã xử lý logic: Gửi trùng type = Bỏ like
    _api.reactToPost(widget.post.id, "LOVE").then((success) {
      if (!success) {
        // Nếu API lỗi -> Revert về trạng thái cũ
        setState(() {
          _isLiked = previousState;
          _reactionCount = previousCount;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                  backgroundImage: NetworkImage(widget.post.authorAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.post.createdAt,
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

            // 2. Content
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.post.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),
              ),

            // 3. Image
            if (widget.post.imageUrl != null &&
                widget.post.imageUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF1F5F9),
                  image: DecorationImage(
                    image: NetworkImage(widget.post.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
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

            // 4. Action Buttons (Like & Comment)
            Row(
              children: [
                // --- NÚT LIKE (Đã tương tác) ---
                InkWell(
                  onTap: _handleLike, // Gọi hàm xử lý like
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked
                              ? PhosphorIconsFill.heart
                              : PhosphorIconsRegular.heart,
                          size: 24,
                          color: _isLiked ? Colors.red : Colors.black87,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "$_reactionCount",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _isLiked ? Colors.red : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // --- NÚT COMMENT ---
                Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.chatCircle,
                      size: 24,
                      color: Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${widget.post.commentCount}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
