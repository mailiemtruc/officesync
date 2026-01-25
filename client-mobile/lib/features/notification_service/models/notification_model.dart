class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String type; // CHAT, REQUEST, TASK, ANNOUNCEMENT...
  final int referenceId; // ID của đối tượng (RequestId, PostId...)
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'GENERAL',
      referenceId: json['referenceId'] ?? 0,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    int? referenceId,
    bool? isRead,
    String? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
