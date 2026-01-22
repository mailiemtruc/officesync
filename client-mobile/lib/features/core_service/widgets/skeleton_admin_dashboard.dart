// File: lib/core/widgets/skeleton_admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonAdminDashboard extends StatelessWidget {
  const SkeletonAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền Shimmer
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      physics: const NeverScrollableScrollPhysics(), // Khóa cuộn khi đang load
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER (Avatar + Tên + Icon Notification)
            Row(
              children: [
                // Avatar
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: 15),
                // Tên & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 150,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                // Icons
                Row(
                  children: [
                    _buildCircle(44),
                    const SizedBox(width: 12),
                    _buildCircle(44),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 2. CHART CARD (Biểu đồ lớn)
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
            ),

            const SizedBox(height: 30),

            // 3. QUICK ACTIONS (Hàng 4 nút tròn)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) => _buildActionItem()),
            ),

            const SizedBox(height: 35),

            // 4. LIST HEADER (Tiêu đề danh sách)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 150,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // 5. COMPANY LIST (Danh sách công ty giả lập)
            Column(children: List.generate(3, (index) => _buildCompanyItem())),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildActionItem() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 50,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 90, // Chiều cao xấp xỉ thẻ thật
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
