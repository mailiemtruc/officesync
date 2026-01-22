// File: lib/core/widgets/skeleton_timesheet_card.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonTimesheetCard extends StatelessWidget {
  const SkeletonTimesheetCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền Shimmer
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Ngày tháng + Trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBar(width: 120, height: 14), // Ngày
                _buildBar(
                  width: 80,
                  height: 24,
                  radius: 12,
                ), // Badge trạng thái
              ],
            ),
            const SizedBox(height: 16),

            // Hàng 2: Giờ Check-in / Check-out
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBar(width: 60, height: 10), // Title "Check In"
                      const SizedBox(height: 8),
                      _buildBar(width: 80, height: 18), // Time
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBar(width: 60, height: 10), // Title "Check Out"
                      const SizedBox(height: 8),
                      _buildBar(width: 80, height: 18), // Time
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Hàng 3: Tổng giờ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBar(width: 100, height: 12),
                _buildBar(width: 40, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
