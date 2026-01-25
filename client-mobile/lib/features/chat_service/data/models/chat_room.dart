// File: chat_room.dart

class ChatRoom {
  final int id;
  final String roomName;
  final String type;
  final String? avatarUrl;
  final String updatedAt; // 👈 Cái này cần được update

  ChatRoom({
    required this.id,
    required this.roomName,
    required this.type,
    this.avatarUrl,
    required this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      roomName: json['roomName'] ?? "Cuộc hội thoại",
      type: json['type'] ?? "PRIVATE",
      avatarUrl: json['roomAvatarUrl'],
      updatedAt: json['updatedAt'] ?? "",
    );
  }

  // ✅ [THÊM MỚI] Hàm này giúp tạo ra bản sao mới với thời gian mới
  ChatRoom copyWith({
    String? updatedAt,
    String?
    lastMessage, // Sau này bạn có thể muốn hiện cả nội dung tin nhắn ngắn
  }) {
    return ChatRoom(
      id: this.id,
      roomName: this.roomName,
      type: this.type,
      avatarUrl: this.avatarUrl,
      updatedAt:
          updatedAt ??
          this.updatedAt, // Nếu có giờ mới thì lấy, không thì giữ cũ
    );
  }
}
