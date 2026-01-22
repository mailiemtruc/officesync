// File: lib/core/widgets/skeleton_director_profile.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonDirectorProfile extends StatelessWidget {
  const SkeletonDirectorProfile({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền Shimmer
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const NeverScrollableScrollPhysics(), // Khóa cuộn khi đang load
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. AVATAR SECTION
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 2. GENERAL INFO
            _buildSectionTitleSkeleton(),
            _buildInputGroupSkeleton(), // Company Name
            _buildInputGroupSkeleton(), // Industry
            _buildInputGroupSkeleton(), // Domain

            const SizedBox(height: 30),

            // 3. ATTENDANCE CONFIG
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitleSkeleton(width: 180),
                // Button "Location" giả lập
                Container(
                  width: 80,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),

            // Row: Lat / Long
            Row(
              children: [
                Expanded(child: _buildInputGroupSkeleton()),
                const SizedBox(width: 10),
                Expanded(child: _buildInputGroupSkeleton()),
              ],
            ),
            _buildInputGroupSkeleton(), // Radius
            // Row: Start / End Time
            Row(
              children: [
                Expanded(child: _buildInputGroupSkeleton()),
                const SizedBox(width: 10),
                Expanded(child: _buildInputGroupSkeleton()),
              ],
            ),

            _buildInputGroupSkeleton(), // Wifi SSID
            _buildInputGroupSkeleton(), // Wifi BSSID

            const SizedBox(height: 30),

            // 4. INTRODUCTION
            _buildSectionTitleSkeleton(),
            const SizedBox(height: 15),
            // Description Area (Box lớn)
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 40),

            // 5. SAVE BUTTON
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Helper: Title
  Widget _buildSectionTitleSkeleton({double width = 150}) {
    return Container(
      width: width,
      height: 20,
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Helper: Label + Input Box
  Widget _buildInputGroupSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        // Label
        Container(
          width: 100,
          height: 14,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // Input Box
        Container(
          width: double.infinity,
          height: 55, // Chiều cao input field chuẩn
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}
