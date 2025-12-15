import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/config/app_colors.dart';

class EmployeeCard extends StatelessWidget {
  final String name;
  final String employeeId;
  final String role;
  final String department;
  final String imageUrl;
  final bool isLocked;

  final bool isSelected;
  final Widget? selectionWidget;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  const EmployeeCard({
    super.key,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.department,
    this.imageUrl = "https://placehold.co/46x46",
    this.isLocked = false,
    this.isSelected = false,
    this.selectionWidget,
    this.onTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isManager = role == "Manager" || role == "Management";
    double opacity = isLocked ? 0.5 : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          // Nếu bị khóa -> không cho chọn (onTap = null)
          onTap: isLocked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Opacity(
              opacity: opacity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  ClipOval(
                    child: Image.network(
                      imageUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 46,
                        height: 46,
                        color: Colors.grey[300],
                        child: Icon(Icons.person, color: Colors.grey[600]),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // --- SỬA LẠI: HIỂN THỊ CHỮ (Locked) ---
                            if (isLocked) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '(Locked)',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            // ---------------------------------------
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Employee ID: $employeeId',
                          style: const TextStyle(
                            color: Color(0xFF555252),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Badges
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (role.isNotEmpty)
                              _buildStatusBadge(role, isManager),
                            if (department.isNotEmpty)
                              _buildBadge(
                                text: department,
                                textColor: const Color(0xFF767676),
                                bgColor: const Color(0xFFEAEBEE),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing: Menu trước, Select sau
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: onMenuTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            PhosphorIcons.dotsThree(PhosphorIconsStyle.bold),
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      if (selectionWidget != null) selectionWidget!,
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String role, bool isManager) {
    if (role == "Unassigned") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          role,
          style: const TextStyle(
            color: Color(0xFF166534),
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return _buildBadge(
      text: role,
      textColor: isManager ? AppColors.primary : const Color(0xFF767676),
      bgColor: isManager ? const Color(0xFFECF1FF) : const Color(0xFFEAEBEE),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
