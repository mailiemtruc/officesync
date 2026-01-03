class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String type; // Loại: TASK, LEAVE, POST...
  final int referenceId; // ID của đối tượng liên quan (VD: ID đơn nghỉ phép)
  final bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  // Hàm chuyển từ JSON (Server trả về) thành Object (Dart dùng được)
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? "Không có tiêu đề",
      body: json['body'] ?? "",
      type: json['type'] ?? "GENERAL",
      referenceId: json['referenceId'] ?? 0,
      isRead:
          json['read'] ??
          false, // Chú ý: Backend trả về 'read' hay 'isRead' tùy JSON, check log kỹ nhé
      createdAt: json['createdAt'] ?? "",
    );
  }
}
