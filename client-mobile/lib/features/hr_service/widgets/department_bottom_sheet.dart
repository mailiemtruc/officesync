import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/department_model.dart';
import 'confirm_bottom_sheet.dart';
import '../presentation/pages/edit_department_page.dart';
import '../presentation/pages/department_details_page.dart'; // Trang vừa tạo
import '../presentation/pages/add_members_page.dart'; // Trang thêm thành viên

class DepartmentBottomSheet extends StatelessWidget {
  final Department department;
  final VoidCallback onDelete;

  const DepartmentBottomSheet({
    super.key,
    required this.department,
    required this.onDelete,
  });

  void _showDeleteDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Delete Department?',
        message:
            'This action cannot be undone. Employees in this department will be moved to "Unassigned".',
        confirmText: 'Delete',
        confirmColor: const Color(0xFFDC2626),
        onConfirm: () {
          Navigator.pop(context);
          onDelete();
        },
      ),
    );
  }

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
            Container(
              width: 35,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
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

            // --- MENU ACTIONS (ĐÃ CẬP NHẬT) ---

            // 1. View Details -> Chuyển sang trang DepartmentDetailsPage
            _buildActionItem(
              icon: PhosphorIcons.listMagnifyingGlass(),
              text: 'View Details & Members',
              color: const Color(0xFF374151),
              onTap: () {
                Navigator.pop(context); // Đóng sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DepartmentDetailsPage(department: department),
                  ),
                );
              },
            ),

            _buildActionItem(
              icon: PhosphorIcons.pencilSimple(),
              text: 'Edit Department Info',
              color: const Color(0xFF374151),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditDepartmentPage(),
                  ),
                );
              },
            ),

            // 2. Add Member -> Chuyển sang trang AddMembersPage
            _buildActionItem(
              icon: PhosphorIcons.userPlus(),
              text: 'Add Member to Dept',
              color: const Color(0xFF374151),
              onTap: () {
                Navigator.pop(context); // Đóng sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddMembersPage(
                      alreadySelectedMembers: [],
                    ), // Truyền list rỗng nếu thêm mới
                  ),
                );
              },
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            _buildActionItem(
              icon: PhosphorIcons.trash(),
              text: 'Delete Department',
              color: const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context);
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
