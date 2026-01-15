import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../data/newsfeed_api.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
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
  final FocusNode _focusNode = FocusNode();

  CommentModel? _replyingTo;
  late Future<List<CommentModel>> _commentsFuture;

  // Biến này chỉ dùng để cập nhật số lượng ảo khi comment xong,
  // không cần hiển thị số tổng nữa nên có thể bỏ hoặc giữ để logic không lỗi
  late int _currentCommentCount;

  @override
  void initState() {
    super.initState();
    _currentCommentCount = widget.post.commentCount;
    _refreshComments();
    _api.viewPost(widget.post.id);
  }

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
    String myAvatar = await _getMyAvatar();

    final success = await _api.sendComment(
      widget.post.id,
      content,
      myAvatar,
      parentId: _replyingTo?.id,
    );

    if (success) {
      _commentCtrl.clear();
      setState(() {
        _replyingTo = null;
        _currentCommentCount++;
      });
      _refreshComments();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send comment.")),
        );
      }
    }
  }

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
                  // --- HEADER POST ---
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
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
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.toTimeAgo(widget.post.createdAt),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- CONTENT ---
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
                  const SizedBox(height: 16),

                  // --- IMAGE ---
                  if (widget.post.imageUrl != null &&
                      widget.post.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                      ), // Thêm chút khoảng cách dưới ảnh
                      child: Image.network(
                        widget.post.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  // ❌ ĐÃ XÓA PHẦN THỐNG KÊ (Tim/Comment) Ở ĐÂY ❌
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // --- COMMENT LIST ---
                  _buildCommentList(),
                ],
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ... (Phần dưới giữ nguyên như cũ: _buildCommentList, _buildCommentItem, _buildInputArea)
  // Để code gọn, bạn giữ nguyên phần Widget _buildCommentList trở xuống ở file trước nhé.
  // Nếu bạn cần tôi paste lại cả phần dưới thì bảo tôi, nhưng nó y hệt file trước, chỉ khác phần build() ở trên.

  // 👇 ĐÂY LÀ PHẦN DƯỚI (Copy lại để bạn đỡ phải tìm)
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
              "No comments yet.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          padding: const EdgeInsets.only(bottom: 20),
          itemBuilder: (context, index) => _buildCommentItem(comments[index]),
        );
      },
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final isReply = comment.parentId != null && comment.parentId != 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply) ...[
            const SizedBox(width: 32),
            Container(
              margin: const EdgeInsets.only(right: 12, top: 12),
              width: 20,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          CircleAvatar(
            radius: isReply ? 16 : 20,
            backgroundImage: NetworkImage(comment.authorAvatar),
            backgroundColor: const Color(0xFFF1F5F9),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Row(
                    children: [
                      Text(
                        DateFormatter.toTimeAgo(comment.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() => _replyingTo = comment);
                          FocusScope.of(context).requestFocus(_focusNode);
                        },
                        child: Text(
                          "Reply",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                    onTap: () => setState(() => _replyingTo = null),
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
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? "Reply..."
                          : "Write a comment...",
                      border: InputBorder.none,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendComment(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _handleSendComment,
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
