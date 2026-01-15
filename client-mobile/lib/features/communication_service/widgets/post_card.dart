import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/post_model.dart';
import '../data/newsfeed_api.dart';
import '/../core/utils/date_formatter.dart'; // ✅ Nhớ import file xử lý ngày tháng vừa tạo

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _reactionCount;
  final _api = NewsfeedApi();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.myReaction != null;
    _reactionCount = widget.post.reactionCount;
  }

  void _handleLike() {
    final previousState = _isLiked;
    final previousCount = _reactionCount;

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _reactionCount--;
      } else {
        _isLiked = true;
        _reactionCount++;
      }
    });

    _api.reactToPost(widget.post.id, "LOVE").then((success) {
      if (!success) {
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
        margin: const EdgeInsets.only(
          bottom: 16,
        ), // ✅ Tăng khoảng cách giữa các bài post (12 -> 16)
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ), // ✅ Tăng padding bên trong cho thoáng (16 -> 20)
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), // Bo góc Card mềm mại hơn
          // ✅ HIỆU ỨNG ĐỔ BÓNG "NỔI" (Elevation)
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF64748B,
              ).withOpacity(0.08), // Màu bóng xanh xám hiện đại
              blurRadius: 24, // Độ nhòe bóng rộng hơn (blur cao)
              offset: const Offset(0, 8), // Bóng đổ xuống dưới
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER (Avatar + Tên + Thời gian)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(
                    2,
                  ), // Viền trắng bao quanh avatar
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 24, // ✅ Tăng kích thước Avatar một chút (22 -> 24)
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: NetworkImage(widget.post.authorAvatar),
                  ),
                ),
                const SizedBox(
                  width: 14,
                ), // ✅ Tăng khoảng cách Avatar <-> Tên (12 -> 14)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(
                            0xFF1E293B,
                          ), // Màu chữ đậm hơn cho dễ đọc
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ), // ✅ TÁCH BIỆT TÊN VÀ THỜI GIAN (Quan trọng)
                      Text(
                        DateFormatter.toTimeAgo(widget.post.createdAt),
                        style: const TextStyle(
                          color: Color(
                            0xFF94A3B8,
                          ), // Màu xám nhạt hiện đại (Slate 400)
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Nút "More" (Ba chấm) trang trí cho đầy đủ
                IconButton(
                  icon: const Icon(
                    PhosphorIconsBold.dotsThree,
                    color: Color(0xFFCBD5E1),
                  ),
                  onPressed: () {},
                ),
              ],
            ),

            const SizedBox(height: 16), // Khoảng cách từ Header xuống Nội dung
            // 2. CONTENT TEXT
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 16,
                ), // ✅ Tăng khoảng cách Chữ <-> Ảnh (12 -> 16)
                child: Text(
                  widget.post.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5, // Giãn dòng cho dễ đọc
                    color: Color(0xFF334155), // Màu chữ Slate 700 (dịu mắt)
                  ),
                ),
              ),

            // 3. IMAGE
            if (widget.post.imageUrl != null &&
                widget.post.imageUrl!.isNotEmpty)
              Container(
                width: double.infinity,
                // Giới hạn chiều cao tối đa để ảnh dọc không chiếm hết màn hình
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    16,
                  ), // ✅ Bo góc ảnh (12-16px là chuẩn đẹp)
                  color: const Color(0xFFF1F5F9),
                  image: DecorationImage(
                    image: NetworkImage(widget.post.imageUrl!),
                    fit: BoxFit.cover, // Cắt ảnh cho vừa khung
                  ),
                ),
                // Hack nhỏ: Dùng AspectRatio hoặc Container rỗng để giữ chỗ
                child: const SizedBox(height: 240),
              )
            // Nếu không có ảnh thì ẩn đi (SizedBox.shrink)
            else if (widget.post.imageUrl == null)
              const SizedBox.shrink(),

            const SizedBox(height: 20), // Khoảng cách Ảnh -> Nút bấm
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // 4. ACTION BUTTONS (Nút Tim & Comment)
            Row(
              children: [
                // --- NÚT LIKE ---
                InkWell(
                  onTap: _handleLike,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isLiked
                          ? const Color(0xFFFEF2F2)
                          : Colors.transparent, // Nền đỏ nhạt khi like
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked
                              ? PhosphorIconsFill.heart
                              : PhosphorIconsRegular.heart,
                          size: 22,
                          color: _isLiked
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$_reactionCount",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _isLiked
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // --- NÚT COMMENT ---
                InkWell(
                  onTap: widget.onTap, // Bấm comment cũng vào chi tiết
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.chatCircle,
                          size: 22,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${widget.post.commentCount}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
