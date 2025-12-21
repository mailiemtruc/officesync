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
    return PostModel(
      id: json['id'],
      content: json['content'] ?? "",
      imageUrl: json['imageUrl'],
      authorId: json['authorId'],
      authorName: json['authorName'] ?? "Unknown",
      // Tạo avatar mặc định nếu null
      authorAvatar:
          json['authorAvatar'] ??
          "https://ui-avatars.com/api/?name=${json['authorName']}&background=random",
      createdAt: json['createdAt'] ?? "",
      reactionCount: json['reactionCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      myReaction: json['myReaction'],
    );
  }
}
