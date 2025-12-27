class NoteModel {
  final int id;
  final String title;
  final String content;
  final bool isPinned;
  final String color; // Lưu chuỗi Hex: "0xFF..."
  final String updatedAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.color,
    required this.updatedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      isPinned:
          json['pinned'] ??
          false, // Check kỹ JSON trả về là 'pinned' hay 'isPinned'
      color: json['color'] ?? '0xFFFFFFFF',
      updatedAt: json['updatedAt'] ?? '',
    );
  }
}
