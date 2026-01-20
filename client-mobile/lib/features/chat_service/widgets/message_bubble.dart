import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../data/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Kiểm tra loại tin nhắn
    bool isImage = message.type == 'IMAGE';

    final bg = isMe ? const Color(0xFF0084FF) : const Color(0xFFE4E6EB);
    final fg = isMe ? Colors.white : Colors.black;

    final radius = BorderRadius.circular(18);
    final borderRadius = isMe
        ? radius.copyWith(bottomRight: const Radius.circular(4))
        : showAvatar
        ? radius.copyWith(bottomLeft: const Radius.circular(4))
        : radius;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Avatar
          if (!isMe) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 14,
                backgroundImage: message.avatarUrl.isNotEmpty
                    ? NetworkImage(message.avatarUrl)
                    : null,
                backgroundColor: Colors.grey[300],
                child: message.avatarUrl.isEmpty
                    ? Text(
                        message.senderName.isNotEmpty
                            ? message.senderName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black87,
                        ),
                      )
                    : null,
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],

          // 2. Cột chứa Nội dung + Thời gian
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Khối nội dung (Ảnh hoặc Chữ)
                Container(
                  padding: isImage
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: borderRadius,
                  ),
                  child: isImage
                      ? ClipRRect(
                          borderRadius: borderRadius,
                          child: Image.network(
                            message.content,
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 150,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (ctx, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                          ),
                        )
                      : SelectableLinkify(
                          text: message.content,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            height: 1.3,
                          ),
                          linkStyle: TextStyle(
                            color: isMe ? Colors.white : Colors.blue[800],
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                          onOpen: (link) async {
                            final Uri url = Uri.parse(link.url);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            } else {
                              print("Không thể mở link: ${link.url}");
                            }
                          },
                        ),
                ),

                // Thời gian (Nằm dưới tin nhắn)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return "";
    try {
      DateTime dt = DateTime.parse(timestamp).toLocal();

      // CHỈ HIỆN GIỜ:PHÚT (Vì ngày đã có Header lo rồi)
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return "";
    }
  }
}
