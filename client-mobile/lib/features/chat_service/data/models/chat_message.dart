class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final String timestamp;
  final bool isMe;
  final String senderName;
  final String avatarUrl;

  // [MỚI] Thêm trường type để biết là 'CHAT' hay 'IMAGE'
  final String type;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.senderName = "",
    this.avatarUrl = "",
    this.type = 'CHAT', // Mặc định là tin nhắn chữ
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myId) {
    String sId = json['senderId'].toString();
    return ChatMessage(
      id: (json['id'] ?? "").toString(),
      senderId: sId,
      recipientId: (json['recipientId'] ?? "").toString(),
      content: json['content'] ?? "",
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      isMe: sId == myId,
      senderName: json['senderName'] ?? "",
      avatarUrl: json['avatarUrl'] ?? "",

      // [MỚI] Map type từ Server về (nếu null thì coi như CHAT)
      type: json['type'] ?? 'CHAT',
    );
  }

  // [MỚI] Cập nhật copyWith để hỗ trợ cả trường type
  ChatMessage copyWith({
    String? senderName,
    String? avatarUrl,
    bool? isMe, // Đổi thành nullable để linh hoạt hơn
    String? type, // [MỚI]
  }) {
    return ChatMessage(
      id: this.id,
      senderId: this.senderId,
      recipientId: this.recipientId,
      content: this.content,
      timestamp: this.timestamp,

      // Nếu truyền vào thì dùng, không thì lấy cái cũ
      isMe: isMe ?? this.isMe,
      senderName: senderName ?? this.senderName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
    );
  }
}