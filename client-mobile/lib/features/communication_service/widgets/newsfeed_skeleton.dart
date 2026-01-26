import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class NewsfeedSkeleton extends StatelessWidget {
  const NewsfeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5, // Giả lập 5 bài viết đang load
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Avatar + Tên)
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 14, color: Colors.white),
                        const SizedBox(height: 6),
                        Container(width: 80, height: 12, color: Colors.white),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Content (Mô phỏng 2 dòng chữ)
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Container(width: 200, height: 14, color: Colors.white),
                const SizedBox(height: 16),

                // 3. Image (Khối chữ nhật lớn)
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Buttons (Like/Comment)
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 60,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
