import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/config/app_colors.dart';
import '../data/models/employee_model.dart';

class EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final bool isSelected;
  final Widget? selectionWidget;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.isSelected = false,
    this.selectionWidget,
    this.onTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    // --- XỬ LÝ DỮ LIỆU ---
    final String name = employee.fullName;

    // 1. Hiển thị Employee Code
    final String displayCode = employee.employeeCode ?? employee.id ?? "N/A";

    final String role = employee.role;
    final bool isLocked = employee.status == "LOCKED";

    // Kiểm tra Avatar có tồn tại không
    final bool hasAvatar =
        employee.avatarUrl != null && employee.avatarUrl!.isNotEmpty;

    final String department = employee.departmentName ?? "No Dept";

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
          onTap: isLocked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Opacity(
              opacity: opacity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Circle
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasAvatar
                          ? Colors.transparent
                          : const Color(0xFFEFF1F5),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: ClipOval(
                      child: hasAvatar
                          ? Image.network(
                              employee.avatarUrl!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildDefaultAvatar(),
                            )
                          : _buildDefaultAvatar(),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên nhân viên
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
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Employee Code
                        Text(
                          'Employee ID: $displayCode',
                          style: const TextStyle(
                            color: Color(0xFF555252),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),

                        //  Badges (Role & Dept)
                        // Thay Wrap bằng Row để ép nằm cùng dòng
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (role.isNotEmpty) ...[
                              _buildStatusBadge(role),
                              // Tạo khoảng cách bằng SizedBox thay vì spacing của Wrap
                              const SizedBox(width: 8),
                            ],

                            // Dùng Flexible để tên phòng ban tự co giãn, không bị xuống dòng
                            if (department.isNotEmpty)
                              Flexible(
                                child: _buildBadge(
                                  text: department,
                                  textColor: const Color(0xFF767676),
                                  bgColor: const Color(0xFFEAEBEE),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Menu Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onMenuTap != null)
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

  Widget _buildDefaultAvatar() {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFFEFF1F5),
      child: Icon(
        PhosphorIcons.user(PhosphorIconsStyle.fill),
        color: const Color(0xFF9CA3AF),
        size: 24,
      ),
    );
  }

  Widget _buildStatusBadge(String role) {
    final List<String> highLevelRoles = [
      "MANAGER",
      "ADMIN",
      "COMPANY_ADMIN",
      "MANAGEMENT",
    ];

    bool isHighLevel = highLevelRoles.contains(role.toUpperCase());

    Color textColor = isHighLevel ? AppColors.primary : const Color(0xFF767676);
    Color bgColor = isHighLevel
        ? const Color(0xFFECF1FF)
        : const Color(0xFFEAEBEE);

    if (role == "Unassigned") {
      textColor = const Color(0xFF166534);
      bgColor = const Color(0xFFDCFCE7);
    }

    return _buildBadge(text: role, textColor: textColor, bgColor: bgColor);
  }

  Widget _buildBadge({
    required String text,
    required Color textColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      //  Bỏ ConstrainedBox(maxWidth: 140)
      // Để Text tự động fill theo không gian còn lại của Flexible bên ngoài
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
