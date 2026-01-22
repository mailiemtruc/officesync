import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/repositories/department_repository_impl.dart';
import '../data/models/department_model.dart';
import 'confirm_bottom_sheet.dart';
import '../presentation/pages/edit_department_page.dart';
import '../presentation/pages/department_details_page.dart';
import '../data/datasources/department_remote_data_source.dart';
import '../../../../core/utils/custom_snackbar.dart';

class DepartmentBottomSheet extends StatelessWidget {
  final DepartmentModel department;
  final VoidCallback onDeleteSuccess;

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
          const storage = FlutterSecureStorage();
          String? userId;
          try {
            String? userInfoStr = await storage.read(key: 'user_info');
            if (userInfoStr != null) {
              final userMap = jsonDecode(userInfoStr);
              userId = userMap['id'].toString();
            }
          } catch (e) {
            print("Error reading user info: $e");
          }

          if (userId == null) {
            if (context.mounted) {
              Navigator.pop(context);
              CustomSnackBar.show(
                context,
                title: 'Session Error',
                message: 'Session expired. Please login again.',
                isError: true,
              );
            }
            return;
          }

          final repo = DepartmentRepositoryImpl(
            remoteDataSource: DepartmentRemoteDataSource(),
          );

          try {
            final bool success = await repo.deleteDepartment(
              userId,
              department.id!,
            );

            if (!context.mounted) return;

            if (success) {
              Navigator.pop(context);
              onDeleteSuccess();
              CustomSnackBar.show(
                context,
                title: 'Success',
                message: 'Department deleted successfully',
                isError: false,
              );
            } else {
              Navigator.pop(context);
              CustomSnackBar.show(
                context,
                title: 'Delete Failed',
                message:
                    'Failed to delete department. Please check dependencies.',
                isError: true,
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.pop(context);
              String msg = e.toString().replaceAll("Exception: ", "");
              CustomSnackBar.show(
                context,
                title: 'Error',
                message: 'Error: $msg',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

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

            // Header Section
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
                            if (department.isHr) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFC7D2FE),
                                    width: 0.5,
                                  ),
                                ),
                                child: const Text(
                                  'HR',
                                  style: TextStyle(
                                    color: Color(0xFF4338CA),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${department.code ?? "N/A"}  |  ${department.memberCount} Members',
                          style: const TextStyle(
                            color: Color(0xFF555252),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // [ĐÃ SỬA] Thêm lại nút đóng và đóng ngoặc đầy đủ
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
                    builder: (context) =>
                        EditDepartmentPage(department: department),
                  ),
                );
                if (result == true) onDeleteSuccess();
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
