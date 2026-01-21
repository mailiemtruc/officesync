import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/newsfeed_api.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/socket_service.dart';

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

  List<CommentModel> _comments = [];
  bool _isLoading = true;

  // Vẫn giữ biến này để sync dữ liệu khi back về, nhưng không hiển thị lên UI
  late int _currentReactionCount;
  late int _currentCommentCount;

  @override
  void initState() {
    super.initState();
    _currentReactionCount = widget.post.reactionCount;
    _currentCommentCount = widget.post.commentCount;

    _api.viewPost(widget.post.id);
    _loadComments();
    _listenSocket();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _listenSocket() {
    SocketService().subscribeToPost(widget.post.id, (data) {
      if (!mounted) return;

      if (data['type'] == 'REACTION_UPDATE') {
        setState(() {
          _currentReactionCount = int.parse(data['reactionCount'].toString());
        });
      } else if (data['content'] != null) {
        try {
          CommentModel newComment = CommentModel.fromJson(data);
          bool exists = _comments.any((c) => c.id == newComment.id);

          if (!exists) {
            setState(() {
              _comments.add(newComment);
              _currentCommentCount++;
            });
          }
        } catch (e) {
          print("Lỗi parse comment socket: $e");
        }
      }
    });
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _api.fetchComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      });
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
          onPressed: () {
            Navigator.pop(context, {
              'reactionCount': _currentReactionCount,
              'commentCount': _currentCommentCount,
            });
          },
        ),
        centerTitle: true,
        title: const Text(
          "Post Details",
          style: TextStyle(
            color: Color(0xFF2260FF),
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
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
                  // --- HEADER ---
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
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Image.network(
                        widget.post.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  // ❌ ĐÃ XÓA PHẦN THỐNG KÊ (Tim/Comment) TẠI ĐÂY THEO YÊU CẦU
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // --- COMMENT LIST ---
                  _buildCommentList(),
                ],
              ),
            ),
          ),

          // --- INPUT AREA ---
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCommentList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_comments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: const Text(
          "No comments yet. Be the first to say something!",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
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
