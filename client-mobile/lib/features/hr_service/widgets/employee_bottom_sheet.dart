import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/employee_model.dart';
import '../presentation/pages/edit_profile_emloyee_page.dart';
import 'confirm_bottom_sheet.dart';

class EmployeeBottomSheet extends StatelessWidget {
  final Employee employee;
  final VoidCallback onToggleLock;
  final VoidCallback onDelete;

  const EmployeeBottomSheet({
    super.key,
    required this.employee,
    required this.onToggleLock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Đảm bảo không vượt quá 600px trên tablet
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Chỉ chiếm chiều cao vừa đủ
          children: [
            const SizedBox(height: 12),
            // Thanh gạch ngang (Handle bar)
            Container(
              width: 35,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Thông tin nhân viên (Header của Sheet)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.network(
                      employee.imageUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 46),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF555252),
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w300,
                            ),
                            children: [
                              TextSpan(text: 'Employee ID: ${employee.id}'),
                              const TextSpan(text: '  |  '),
                              TextSpan(text: employee.department),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nút đóng nhanh (Option)
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
              icon: PhosphorIcons.userList(),
              text: 'View Employee Profile',
              color: const Color(0xFF374151),
              onTap: () {},
            ),

            _buildActionItem(
              icon: PhosphorIcons.pencilSimple(),
              text: 'Edit Information',
              color: const Color(0xFF374151),
              onTap: () {
                Navigator.pop(context); // 1. Đóng BottomSheet trước

                // 2. Chuyển sang trang Edit
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfileEmployeePage(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // --- NÚT LOCK / UNLOCK ---
            _buildActionItem(
              icon: employee.isLocked
                  ? PhosphorIcons.lockOpen()
                  : PhosphorIcons.lock(),
              text: employee.isLocked ? 'Unlock Account' : 'Lock Account',
              color: employee.isLocked ? Colors.green : const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context); // Đóng menu chính trước

                if (employee.isLocked) {
                  // Mở khóa ngay lập tức (không cần hỏi)
                  onToggleLock();
                } else {
                  // Nếu Khóa -> Gọi trực tiếp showModalBottomSheet ở đây
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => ConfirmBottomSheet(
                      title: 'Suspend Access?',
                      message:
                          'Employee ${employee.name} will not be able to log in to the system.',
                      confirmText: 'Suspend',
                      confirmColor: const Color(0xFFF97316), // Màu cam
                      onConfirm: () {
                        Navigator.pop(context); // Đóng confirm sheet
                        onToggleLock(); // Thực hiện khóa
                      },
                    ),
                  );
                }
              },
            ),

            // --- NÚT DELETE ---
            _buildActionItem(
              icon: PhosphorIcons.trash(),
              text: 'Delete Employee',
              color: const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context); // Đóng menu chính trước

                // Gọi trực tiếp showModalBottomSheet ở đây
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => ConfirmBottomSheet(
                    title: 'Delete Employee?',
                    message:
                        'This action cannot be undone. All data associated with ${employee.name} will be permanently deleted.',
                    confirmText: 'Delete',
                    confirmColor: const Color(0xFFDC2626), // Màu đỏ
                    onConfirm: () {
                      Navigator.pop(context); // Đóng confirm sheet
                      onDelete(); // Thực hiện xóa
                    },
                  ),
                );
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
