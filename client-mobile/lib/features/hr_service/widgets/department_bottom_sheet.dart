import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/department_model.dart';

class DepartmentBottomSheet extends StatelessWidget {
  final Department department;
  final VoidCallback onDelete;

  const DepartmentBottomSheet({
    super.key,
    required this.department,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
            Container(
              width: 35,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header Bottom Sheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Icon hộp màu cam nhạt như trong thiết kế Stack của bạn
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: department.themeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                      color: department.themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
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
                        Text(
                          'Code: ${department.code}  |  ${department.memberCount} Members',
                          style: const TextStyle(
                            color: Color(0xFF555252),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // --- MENU ACTIONS ---
            _buildActionItem(
              icon: PhosphorIcons.listMagnifyingGlass(),
              text: 'View Details & Members',
              color: const Color(0xFF374151),
              onTap: () {},
            ),

            _buildActionItem(
              icon: PhosphorIcons.pencilSimple(),
              text: 'Edit Department Info',
              color: const Color(0xFF374151),
              onTap: () {},
            ),

            _buildActionItem(
              icon: PhosphorIcons.userPlus(),
              text: 'Add Member to Dept',
              color: const Color(0xFF374151),
              onTap: () {},
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            _buildActionItem(
              icon: PhosphorIcons.trash(),
              text: 'Delete Department',
              color: const Color(0xFFDC2626), // Màu đỏ
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
