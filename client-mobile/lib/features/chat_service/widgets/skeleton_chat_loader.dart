import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonChatLoader extends StatelessWidget {
  const SkeletonChatLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 15,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        reverse: true, // Đảo ngược để giống chat thật
        itemBuilder: (context, index) {
          // Logic: Chẵn nằm phải, Lẻ nằm trái
          bool isMe = index % 2 == 0;
          double width = (index % 3 + 1) * 80.0; // Random độ dài

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                // Avatar bên trái (nếu không phải mình)
                if (!isMe) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Bong bóng chat
                Container(
                  width: width,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
