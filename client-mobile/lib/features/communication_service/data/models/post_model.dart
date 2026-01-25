class PostModel {
  final int id;
  final String content;
  final String? imageUrl;
  final int authorId;
  final String authorName;
  final String authorAvatar;
  final String createdAt;
  final int reactionCount;
  final int commentCount;
  final String? myReaction; // "LOVE", "LIKE" hoặc null

  PostModel({
    required this.id,
    required this.content,
    this.imageUrl,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.createdAt,
    required this.reactionCount,
    required this.commentCount,
    this.myReaction,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // ✅ [THÊM MỚI] Xử lý chuỗi thời gian: Cắt bỏ phần nano giây thừa
    String rawDate = json['createdAt'] ?? "";

    // Ví dụ Server trả về: 2026-01-25T23:45:06.46564592 (quá dài)
    // Dart chỉ hiểu đến:   2026-01-25T23:45:06.465645 (26 ký tự)
    if (rawDate.length > 26) {
      rawDate = rawDate.substring(0, 26);
    }

    return PostModel(
      id: json['id'],
      content: json['content'] ?? "",
      imageUrl: json['imageUrl'],
      authorId: json['authorId'],
      authorName: json['authorName'] ?? "Unknown",
      authorAvatar:
          json['authorAvatar'] ??
          "https://ui-avatars.com/api/?name=${json['authorName']}&background=random",

      createdAt:
          rawDate, // 👈 Thay json['createdAt'] bằng biến rawDate vừa xử lý

      reactionCount: json['reactionCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      myReaction: json['myReaction'],
    );
  }

  // ✅ BẠN ĐANG THIẾU ĐOẠN NÀY NÊN BỊ ĐỎ:
  PostModel copyWith({
    int? reactionCount,
    int? commentCount,
    String? myReaction,
    bool clearReaction = false, // Cờ để xóa reaction (khi bỏ like)
  }) {
    return PostModel(
      id: id,
      content: content,
      imageUrl: imageUrl,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
      // Nếu có truyền giá trị mới thì lấy, không thì giữ nguyên cái cũ
      reactionCount: reactionCount ?? this.reactionCount,
      commentCount: commentCount ?? this.commentCount,
      // Nếu cờ clearReaction = true thì set null, ngược lại lấy giá trị mới hoặc giữ nguyên
      myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
    );
  }
}
