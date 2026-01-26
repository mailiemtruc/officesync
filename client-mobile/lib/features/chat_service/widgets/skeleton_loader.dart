// file: lib/presentation/widgets/skeleton_loader.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonListLoader extends StatelessWidget {
  const SkeletonListLoader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Tạo hiệu ứng lấp lánh
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!, // Màu nền xám nhạt
      highlightColor: Colors.grey[100]!, // Màu sáng chạy qua chạy lại
      child: ListView.builder(
        itemCount: 10, // Giả lập 10 dòng đang load
        padding: const EdgeInsets.all(0),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 1. Avatar giả (Hình tròn)
                Container(
                  width: 56, // Radius 28 * 2
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Text giả (2 dòng hình chữ nhật)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên người dùng
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Nội dung tin nhắn ngắn hơn chút
                      Container(
                        width: 150,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
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
