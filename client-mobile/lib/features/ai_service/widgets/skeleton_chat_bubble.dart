// File: lib/core/widgets/skeleton_chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonChatBubble extends StatelessWidget {
  const SkeletonChatBubble({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền Shimmer
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return Align(
      alignment:
          Alignment.centerLeft, // Mặc định skeleton nằm bên trái (người nhận)
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Hiệu ứng Shimmer
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          period: const Duration(milliseconds: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBar(180),
              const SizedBox(height: 10),
              _buildBar(120),
              const SizedBox(height: 10),
              _buildBar(80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(double width) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
