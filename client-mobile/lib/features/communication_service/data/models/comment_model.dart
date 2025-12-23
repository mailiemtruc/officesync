class CommentModel {
  final int id;
  final String content;
  final int? parentId; // Có thể null nếu không phải reply
  final int userId;
  final String authorName;
  final String authorAvatar;
  final String createdAt;

  CommentModel({
    required this.id,
    required this.content,
    this.parentId,
    required this.userId,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? 0,
      content: json['content'] ?? "",
      parentId: json['parentId'],
      userId: json['userId'] ?? 0,
      authorName: json['authorName'] ?? "Unknown User",
      // Nếu avatar null hoặc rỗng thì dùng ảnh mặc định
      authorAvatar:
          (json['authorAvatar'] != null &&
              json['authorAvatar'].toString().isNotEmpty)
          ? json['authorAvatar']
          : "https://ui-avatars.com/api/?name=User&background=random",
      // Cắt chuỗi ngày tháng cho gọn (VD: 2025-12-22T10:00:00 -> 2025-12-22)
      createdAt: json['createdAt'] != null
          ? json['createdAt'].toString().split('T')[0]
          : "Just now",
    );
  }
}
