class NoteModel {
  final int id;
  final String title;
  final String content;
  final String color;
  final bool isPinned;
  final String updatedAt;
  final String? pin; // [MỚI] Thêm trường này (có thể null)

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.color,
    required this.isPinned,
    required this.updatedAt,
    this.pin, // [MỚI]
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      color: json['color'] ?? '0xFFFFFFFF',
      isPinned:
          json['isPinned'] ??
          json['pinned'] ??
          false, // Xử lý cả 2 key cho chắc
      updatedAt: json['updatedAt'] ?? DateTime.now().toIso8601String(),
      pin: json['pin'], // [MỚI]
    );
  }
}
