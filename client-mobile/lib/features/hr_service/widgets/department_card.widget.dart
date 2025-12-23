import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/department_model.dart';

class DepartmentCard extends StatelessWidget {
  final DepartmentModel department;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  const DepartmentCard({
    super.key,
    required this.department,
    this.onTap,
    this.onMenuTap,
  });

  // Hàm chuyển đổi mã Hex (#RRGGBB) sang Color object
  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.blue;
    }
    try {
      final buffer = StringBuffer();
      if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lấy màu sắc từ model
    final Color themeColor = _parseColor(department.color);

    // 2. Lấy tên quản lý
    final String managerName = department.manager?.fullName ?? "No Manager";

    // 3. Logic Avatar
    final String? avatarUrl = department.manager?.avatarUrl;
    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            // [CẬP NHẬT] Đổ bóng đậm hơn (0.1)
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // --- THANH MÀU BÊN TRÁI ---
                  Container(width: 4, color: themeColor),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- HEADER: Tên phòng ban & Code ---
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
                                        fontSize: 16,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // [CẬP NHẬT] Code đậm hơn (w500)
                                    Text(
                                      'Code: ${department.code ?? "N/A"}',
                                      style: const TextStyle(
                                        color: Color(0xFF9E9E9E),
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight:
                                            FontWeight.w500, // Đậm hơn xíu
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

                          // --- FOOTER: Manager Info & Member Count ---
                          Row(
                            children: [
                              // [CẬP NHẬT] Avatar Manager
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  // Nếu không có ảnh thì nền xám nhạt
                                  color: hasAvatar
                                      ? Colors.transparent
                                      : const Color(0xFFE0E0E0),
                                ),
                                child: ClipOval(
                                  child: hasAvatar
                                      ? Image.network(
                                          avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              _buildDefaultAvatar(),
                                        )
                                      : _buildDefaultAvatar(), // Gọi hàm tạo icon mặc định
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Tên & Chức danh Manager
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MANAGER',
                                      style: TextStyle(
                                        color: Color(0xFF9E9E9E),
                                        fontSize: 10,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      managerName,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Badge số lượng thành viên
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      PhosphorIcons.usersThree(
                                        PhosphorIconsStyle.fill,
                                      ),
                                      size: 14,
                                      color: themeColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${department.memberCount} Members',
                                      style: TextStyle(
                                        color: themeColor,
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

  // [MỚI] Hàm tạo Avatar mặc định (Icon xám trên nền xám nhạt)
  Widget _buildDefaultAvatar() {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFEFF1F5), // Màu nền xám nhạt
      child: const Icon(
        Icons.person,
        color: Color(0xFF9CA3AF), // Màu icon xám đậm hơn
        size: 24,
      ),
    );
  }
}
