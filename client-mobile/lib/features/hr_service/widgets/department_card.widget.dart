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

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.blue;
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
    final Color themeColor = _parseColor(department.color);

    String managerName = department.manager?.fullName ?? "No Manager";
    String? avatarUrl = department.manager?.avatarUrl;
    if (avatarUrl != null && avatarUrl.trim().isEmpty) avatarUrl = null;
    final bool hasAvatar = avatarUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.06,
            ), // [UPDATE] Shadow nhẹ hơn cho hiện đại
            blurRadius: 12,
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
                  // Thanh màu bên trái
                  Container(width: 4, color: themeColor),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- HEADER ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // [UPDATE] Row chứa Tên + Badge HR
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            department.name,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // [NEW] Hiển thị Badge nếu là HR
                                        if (department.isHr) ...[
                                          const SizedBox(width: 8),
                                          _buildHrBadge(),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${department.code ?? "N/A"}',
                                      style: const TextStyle(
                                        color: Color(0xFF9E9E9E),
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (onMenuTap != null)
                                GestureDetector(
                                  onTap: onMenuTap,
                                  child: Container(
                                    // Tăng vùng bấm
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      PhosphorIcons.dotsThree(
                                        PhosphorIconsStyle.bold,
                                      ),
                                      color: const Color(0xFFBDBDBD),
                                      size: 24,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // --- FOOTER ---
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasAvatar
                                      ? Colors.transparent
                                      : const Color(0xFFF3F4F6),
                                ),
                                child: ClipOval(
                                  child: hasAvatar
                                      ? Image.network(
                                          avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              _buildDefaultAvatar(),
                                        )
                                      : _buildDefaultAvatar(),
                                ),
                              ),
                              const SizedBox(width: 12),
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
                              // Member Badge
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

  // [NEW] Widget Badge HR đẹp mắt
  Widget _buildHrBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFC7D2FE), // Viền xanh Indigo nhạt
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), // Icon uy tín
            size: 12,
            color: const Color(0xFF4338CA), // Màu icon xanh Indigo đậm
          ),
          const SizedBox(width: 4),
          const Text(
            'HR Office',
            style: TextStyle(
              color: Color(0xFF4338CA),
              fontSize: 10,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFEFF1F5),
      child: Icon(
        PhosphorIcons.user(PhosphorIconsStyle.fill),
        color: const Color(0xFF9CA3AF),
        size: 20,
      ),
    );
  }
}
