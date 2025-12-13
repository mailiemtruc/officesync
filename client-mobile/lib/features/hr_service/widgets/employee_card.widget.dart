import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';

class EmployeeCard extends StatelessWidget {
  final String name;
  final String employeeId;
  final String role;
  final String department;
  final String imageUrl;
  final bool isLocked;
  final VoidCallback? onTap;
  final VoidCallback? onMenuTap; // Thêm callback này

  const EmployeeCard({
    super.key,
    required this.name,
    required this.employeeId,
    required this.role,
    required this.department,
    this.imageUrl = "https://placehold.co/46x46",
    this.isLocked = false,
    this.onTap,
    this.onMenuTap, // Thêm vào constructor
  });

  @override
  Widget build(BuildContext context) {
    bool isManager = role == "Manager";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar (Opacity khi Locked)
                Opacity(
                  opacity: isLocked ? 0.5 : 1.0,
                  child: ClipOval(
                    child: Image.network(
                      imageUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 46,
                          height: 46,
                          color: Colors.grey[300],
                          child: Icon(Icons.person, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Thông tin chi tiết
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên + (Locked)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isLocked ? Colors.grey : Colors.black,
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
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      // ID
                      Opacity(
                        opacity: isLocked ? 0.5 : 1.0,
                        child: Text(
                          'Employee ID: $employeeId',
                          style: const TextStyle(
                            color: Color(0xFF555252),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Badge Role & Department
                      Opacity(
                        opacity: isLocked ? 0.5 : 1.0,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildBadge(
                              text: role,
                              textColor: isLocked
                                  ? const Color(0xFF9E9E9E)
                                  : (isManager
                                        ? AppColors.primary
                                        : const Color(0xFF767676)),
                              bgColor: isLocked
                                  ? const Color(0xFFF5F5F5)
                                  : (isManager
                                        ? const Color(0xFFECF1FF)
                                        : const Color(0xFFEAEBEE)),
                            ),

                            _buildBadge(
                              text: department,
                              textColor: isLocked
                                  ? const Color(0xFF9E9E9E)
                                  : const Color(0xFF767676),
                              bgColor: isLocked
                                  ? const Color(0xFFF5F5F5)
                                  : const Color(0xFFEAEBEE),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Icon (Nút 3 chấm)
                Opacity(
                  opacity: isLocked ? 0.5 : 1.0,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      PhosphorIcons.dotsThree(PhosphorIconsStyle.bold),
                      color: Colors.grey,
                    ),
                    onPressed: onMenuTap, // Gọi hàm khi nhấn
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
