import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/newsfeed_api.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../../../core/config/app_colors.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _api = NewsfeedApi();
  final _storage = const FlutterSecureStorage();
  final _commentCtrl = TextEditingController();

  // ✅ Biến điều khiển focus và trạng thái reply
  final FocusNode _focusNode = FocusNode();
  CommentModel? _replyingTo;

  late Future<List<CommentModel>> _commentsFuture;
  late int _currentCommentCount;

  @override
  void initState() {
    super.initState();
    _currentCommentCount = widget.post.commentCount;
    _refreshComments();
    // ✅ GỌI HÀM NÀY: Báo cho server biết user đang xem bài viết
    _api.viewPost(widget.post.id);
  }

  // ✅ BỔ SUNG: Hàm dispose để giải phóng bộ nhớ khi thoát màn hình
  @override
  void dispose() {
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _refreshComments() {
    setState(() {
      _commentsFuture = _api.fetchComments(widget.post.id);
    });
  }

  // ✅ THÊM HÀM LẤY AVATAR
  Future<String> _getMyAvatar() async {
    String? userInfoStr = await _storage.read(key: 'user_info');
    if (userInfoStr != null) {
      return jsonDecode(userInfoStr)['avatarUrl'] ?? "";
    }
    return "";
  }

  Future<void> _handleSendComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;

    FocusScope.of(context).unfocus();
    // Lưu ý: Không clear text ngay để lỡ gửi lỗi user đỡ phải nhập lại
    String myAvatar = await _getMyAvatar();
    final success = await _api.sendComment(
      widget.post.id,
      content,
      myAvatar, // Truyền avatar vào
      parentId: _replyingTo?.id,
    );

    if (success) {
      _commentCtrl.clear(); // ✅ Gửi thành công mới xóa text

      setState(() {
        _replyingTo = null; // Reset trạng thái reply
        _currentCommentCount++; // Tăng số lượng hiển thị ngay lập tức (Optimistic UI)
      });

      _refreshComments(); // Load lại dữ liệu mới nhất từ server
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send comment. Please try again."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // --- HEADER ---
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

      // --- BODY ---
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thông tin người đăng bài
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(
                            widget.post.authorAvatar,
                          ),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(width: 12),
                        Column(
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
                      ],
                    ),
                  ),

                  // 2. Nội dung bài viết
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      widget.post.content,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Ảnh bài viết (nếu có)
                  if (widget.post.imageUrl != null &&
                      widget.post.imageUrl!.isNotEmpty)
                    Image.network(
                      widget.post.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(),
                    ),

                  // 4. Thống kê (Like / Comment)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsRegular.heart, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "${widget.post.reactionCount}",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(width: 20),

                        const Icon(PhosphorIconsRegular.chatCircle, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          "$_currentCommentCount",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // 5. Danh sách bình luận
                  _buildCommentList(),
                ],
              ),
            ),
          ),

          // --- FOOTER: NHẬP BÌNH LUẬN ---
          _buildInputArea(),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách Comment
  Widget _buildCommentList() {
    return FutureBuilder<List<CommentModel>>(
      future: _commentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: const Text(
              "No comments yet.\nBe the first to share your thoughts!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, indent: 70),
          itemBuilder: (context, index) {
            return _buildCommentItem(comments[index]);
          },
        );
      },
    );
  }

  // Widget hiển thị 1 dòng Comment
  Widget _buildCommentItem(CommentModel comment) {
    // Kiểm tra reply để thụt lề
    final isReply = comment.parentId != null && comment.parentId != 0;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 60 : 20,
        right: 20,
        top: 16,
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage: NetworkImage(comment.authorAvatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      comment.createdAt,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF334155),
                  ),
                ),

                // Nút Reply
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    // ✅ Logic khi bấm Reply
                    setState(() {
                      _replyingTo = comment;
                    });
                    // Tự động bật bàn phím
                    FocusScope.of(context).requestFocus(_focusNode);
                  },
                  child: const Text(
                    "Reply",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget Thanh nhập liệu
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // UI hiển thị khi đang Reply
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 12),
              child: Row(
                children: [
                  Text(
                    "Replying to ${_replyingTo!.authorName}",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingTo = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 45,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentCtrl,
                    focusNode: _focusNode, // ✅ Gắn FocusNode
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? "Reply to ${_replyingTo!.authorName}..."
                          : "Write a comment...",
                      border: InputBorder.none,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendComment(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _handleSendComment,
                // ✅ Đã sửa: Xóa 'const' để tránh lỗi với AppColors.primary
                icon: Icon(
                  PhosphorIconsFill.paperPlaneRight,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
