import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/models/department_model.dart';
import 'confirm_bottom_sheet.dart';
import '../presentation/pages/edit_department_page.dart'; // Đường dẫn tới trang edit
import '../presentation/pages/department_details_page.dart'; // Đường dẫn tới trang details
import '../domain/repositories/department_repository.dart'; // Import Repo
import '../data/datasources/department_remote_data_source.dart'; // Import DataSource

class DepartmentBottomSheet extends StatelessWidget {
  final DepartmentModel department;
  final VoidCallback onDeleteSuccess; // Callback khi xóa thành công

  const DepartmentBottomSheet({
    super.key,
    required this.department,
    required this.onDeleteSuccess,
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
        onConfirm: () async {
          // Gọi API Xóa
          final repo = DepartmentRepository(
            remoteDataSource: DepartmentRemoteDataSource(),
          );
          try {
            await repo.deleteDepartment(department.id!);
            Navigator.pop(context); // Đóng Dialog Confirm
            Navigator.pop(context); // Đóng BottomSheet Menu
            onDeleteSuccess(); // Refresh list ở trang chủ
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Department deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  // Hàm parse màu
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
    final themeColor = _parseColor(department.color);

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
                      color: themeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                      color: themeColor,
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
                          'Code: ${department.code ?? "N/A"}  |  ${department.memberCount} Members',
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

            // View Details
            _buildActionItem(
              icon: PhosphorIcons.listMagnifyingGlass(),
              text: 'View Details & Members',
              color: const Color(0xFF374151),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DepartmentDetailsPage(department: department),
                  ),
                );
              },
            ),

            // Edit Department
            _buildActionItem(
              icon: PhosphorIcons.pencilSimple(),
              text: 'Edit Department Info',
              color: const Color(0xFF374151),
              onTap: () async {
                Navigator.pop(context);
                final bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditDepartmentPage(
                      department: department,
                    ), // Truyền model vào
                  ),
                );
                if (result == true) onDeleteSuccess(); // Refresh nếu có sửa
              },
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Delete
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
