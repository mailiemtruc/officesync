class ChatRoom {
  final int id;
  final String roomName;
  final String type; // PRIVATE, GROUP
  final String? avatarUrl;
  final String updatedAt;

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
      // Xử lý null safety: Nếu tên phòng null thì hiển thị tạm
      roomName: json['roomName'] ?? "Cuộc hội thoại",
      type: json['type'] ?? "PRIVATE",
      avatarUrl: json['roomAvatarUrl'],
      updatedAt: json['updatedAt'] ?? "",
    );
  }
}
