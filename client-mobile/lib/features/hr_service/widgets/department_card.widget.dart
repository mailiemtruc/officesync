import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/department_model.dart';

class DepartmentCard extends StatelessWidget {
  final Department department;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  const DepartmentCard({
    super.key,
    required this.department,
    this.onTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Bo góc thẻ
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ClipRRect để cắt thanh màu bên trái cho gọn trong góc bo
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              // Giúp thanh màu bên trái cao bằng thẻ
              child: Row(
                children: [
                  // 1. THANH MÀU BÊN TRÁI (Vertical Color Bar)
                  Container(
                    width: 4, // Độ dày thanh màu
                    color: department.themeColor, // Màu theo phòng ban
                  ),

                  // 2. NỘI DUNG CHÍNH
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- HEADER: Tên phòng + Code + Menu ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      department.name,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16, // Font size tiêu đề
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${department.code}',
                                      style: const TextStyle(
                                        color: Color(
                                          0xFF9E9E9E,
                                        ), // Màu xám nhạt
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Nút 3 chấm
                              GestureDetector(
                                onTap: onMenuTap,
                                child: Icon(
                                  PhosphorIcons.dotsThree(
                                    PhosphorIconsStyle.bold,
                                  ),
                                  color: const Color(0xFFBDBDBD),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // --- BOTTOM: Avatar + Manager Info + Member Badge ---
                          Row(
                            children: [
                              // AVATAR: Kích thước 46x46 (Giống Employee Card)
                              ClipOval(
                                child: Image.network(
                                  department.managerImageUrl,
                                  width: 46,
                                  height: 46,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 46,
                                      height: 46,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(width: 12),

                              // THÔNG TIN QUẢN LÝ
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MANAGER',
                                      style: TextStyle(
                                        color: Color(
                                          0xFF9E9E9E,
                                        ), // Màu xám tiêu đề nhỏ
                                        fontSize: 11,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      department.managerName,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // BADGE SỐ LƯỢNG THÀNH VIÊN
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  // Màu nền nhạt (Opacity 0.1)
                                  color: department.themeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      PhosphorIcons.usersThree(
                                        PhosphorIconsStyle.fill,
                                      ),
                                      size: 16,
                                      color: department.themeColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${department.memberCount} Members',
                                      style: TextStyle(
                                        color: department.themeColor,
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
        ),
      ),
    );
  }
}
