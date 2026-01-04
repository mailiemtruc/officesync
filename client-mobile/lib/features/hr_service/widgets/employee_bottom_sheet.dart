import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../data/models/employee_model.dart';
import '../presentation/pages/edit_profile_emloyee_page.dart';
import 'confirm_bottom_sheet.dart';
import '../presentation/pages/employee_profile_page.dart';

class EmployeeBottomSheet extends StatelessWidget {
  final EmployeeModel employee; // Sửa thành EmployeeModel
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

            // Header: Avatar + Tên + ID + Phòng ban
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child:
                          (employee.avatarUrl != null &&
                              employee.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              employee.avatarUrl!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              // Nếu lỗi ảnh -> Dùng avatar mặc định
                              errorBuilder: (_, __, ___) =>
                                  _buildDefaultAvatar(),
                            )
                          // Nếu không có ảnh -> Dùng avatar mặc định
                          : _buildDefaultAvatar(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
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
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Employee ID: ${employee.employeeCode ?? "N/A"}',
                              ),
                              const TextSpan(text: '  |  '),
                              TextSpan(
                                text:
                                    employee.departmentName ?? "No Department",
                              ),
                            ],
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
              icon: PhosphorIcons.userList(),
              text: 'View Employee Profile',
              color: const Color(0xFF374151),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EmployeeProfilePage(employee: employee),
                  ),
                );
              },
            ),

            _buildActionItem(
              icon: PhosphorIcons.pencilSimple(),
              text: 'Edit Information',
              color: const Color(0xFF374151),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfileEmployeePage(employee: employee),
                  ),
                );

                if (context.mounted) {
                  Navigator.pop(context, result);
                }
              },
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // --- LOCK ACCOUNT ---
            _buildActionItem(
              icon: (employee.status == "LOCKED")
                  ? PhosphorIcons.lockOpen()
                  : PhosphorIcons.lock(),
              text: (employee.status == "LOCKED")
                  ? 'Unlock Account'
                  : 'Lock Account',
              color: (employee.status == "LOCKED")
                  ? Colors.green
                  : const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context);
                if (employee.status == "LOCKED") {
                  onToggleLock(); // Unlock ngay
                } else {
                  // Xác nhận Lock
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => ConfirmBottomSheet(
                      title: 'Suspend Access?',
                      message:
                          'Employee ${employee.fullName} will not be able to log in to the system.',
                      confirmText: 'Suspend',
                      confirmColor: const Color(0xFFF97316),
                      onConfirm: () {
                        Navigator.pop(context);
                        onToggleLock();
                      },
                    ),
                  );
                }
              },
            ),

            // --- DELETE EMPLOYEE ---
            _buildActionItem(
              icon: PhosphorIcons.trash(),
              text: 'Delete Employee',
              color: const Color(0xFFDC2626),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => ConfirmBottomSheet(
                    title: 'Delete Employee?',
                    message: 'This action cannot be undone...',
                    confirmText: 'Delete',
                    confirmColor: const Color(0xFFDC2626),
                    onConfirm: () async {
                      // [SỬA] Thêm async
                      // Gọi hàm xóa và đóng dialog
                      Navigator.pop(context);
                      onDelete(); // Logic thực tế nằm ở trang EmployeePage
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

  // Helper tạo avatar mặc định (giống EmployeeCard)
  Widget _buildDefaultAvatar() {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      color: const Color(0xFFEFF1F5), // Màu nền xám
      child: Icon(
        // [ĐÃ SỬA] Đổi sang Phosphor Icon
        PhosphorIcons.user(PhosphorIconsStyle.fill),
        color: const Color(0xFF9CA3AF), // Màu icon xám đậm
        size: 24,
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    // [QUAN TRỌNG] Bọc trong Material để InkWell vẽ được hiệu ứng sóng nước
    return Material(
      color: Colors.transparent, // Nền trong suốt để không che background trắng
      child: InkWell(
        onTap: onTap,
        // [MỚI] Tùy chỉnh màu hiệu ứng lan tỏa dựa theo màu icon (VD: Xóa thì lan màu đỏ nhạt)
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
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
      ),
    );
  }
}
