// File: lib/core/widgets/skeleton_company_item.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonCompanyItem extends StatelessWidget {
  const SkeletonCompanyItem({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền Shimmer
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Bóng mờ nhẹ cho giống thật
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Row(
          children: [
            // 1. Avatar Box (48x48)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(width: 16),

            // 2. Info (Name + Domain)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Line
                  Container(
                    width: double.infinity, // Chiếm hết chiều ngang còn lại
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Domain Line (Ngắn hơn chút)
                  Container(
                    width: 120,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // 3. Status Badge (Pill shape)
            Container(
              width: 70,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
