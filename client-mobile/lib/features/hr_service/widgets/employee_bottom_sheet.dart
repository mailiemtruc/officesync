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
                    child:
                        (employee.avatarUrl != null &&
                            employee.avatarUrl!.isNotEmpty)
                        ? Image.network(
                            employee.avatarUrl!,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, size: 46),
                          )
                        : const Icon(Icons.person, size: 46),
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
                              fontWeight: FontWeight.w300,
                            ),
                            children: [
                              TextSpan(
                                text: 'ID: ${employee.employeeCode ?? "N/A"}',
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
              onTap: () {
                Navigator.pop(context);
                // Truyền object employee sang trang edit
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfileEmployeePage(employee: employee),
                  ),
                );
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
                    message:
                        'This action cannot be undone. All data associated with ${employee.fullName} will be permanently deleted.',
                    confirmText: 'Delete',
                    confirmColor: const Color(0xFFDC2626),
                    onConfirm: () {
                      Navigator.pop(context);
                      onDelete();
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
