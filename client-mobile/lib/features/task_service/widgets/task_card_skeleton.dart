// lib/features/task_service/widgets/task_card_skeleton.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TaskCardSkeleton extends StatelessWidget {
  const TaskCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu nền của các khối xương (thường là màu xám nhạt)
    const Color boneColor = Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!, // Màu gốc (xám tối hơn xíu)
        highlightColor: Colors.grey[100]!, // Màu lướt qua (sáng)
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 1. Thanh dọc bên trái (Status Bar giả)
              Container(
                width: 6,
                decoration: const BoxDecoration(
                  color: boneColor,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(10),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Hàng Title + Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title giả
                          Container(
                            width: 150,
                            height: 16,
                            decoration: BoxDecoration(
                              color: boneColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Badge giả
                          Container(
                            width: 60,
                            height: 20,
                            decoration: BoxDecoration(
                              color: boneColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. Description giả (2 dòng)
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: boneColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 200,
                        height: 12,
                        decoration: BoxDecoration(
                          color: boneColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: boneColor),
                      const SizedBox(height: 12),

                      // 4. Footer (Date + Priority)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Date giả
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: boneColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Priority giả
                          Container(
                            width: 50,
                            height: 12,
                            decoration: BoxDecoration(
                              color: boneColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
