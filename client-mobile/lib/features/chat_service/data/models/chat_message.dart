class ChatMessage {
  final String content;
  final String sender;
  final String type;
  final String timestamp;

  ChatMessage({
    required this.content,
    required this.sender,
    required this.type,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] ?? '',
      sender: json['sender'].toString(),
      type: json['type'] ?? 'CHAT',
      timestamp: json['timestamp'] ?? '',
    );
  }
}
