// File: lib/core/widgets/skeleton_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonAnalyticsScreen extends StatelessWidget {
  const SkeletonAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền Shimmer
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(), // Khóa cuộn khi đang load
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. STATS CARDS (2 thẻ hàng ngang)
            Row(
              children: [
                Expanded(child: _buildStatCardSkeleton()),
                const SizedBox(width: 15),
                Expanded(child: _buildStatCardSkeleton()),
              ],
            ),
            const SizedBox(height: 30),

            // 2. CHART TITLE & CHART AREA
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 30),

            // 3. RECENT USERS LIST
            Container(
              width: 180,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 15),

            // Giả lập 5 user item
            Column(
              children: List.generate(5, (index) => _buildUserItemSkeleton()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardSkeleton() {
    return Container(
      height: 100, // Chiều cao ước lượng của thẻ stat
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildUserItemSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          // Info Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 100,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status Badge
          Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
