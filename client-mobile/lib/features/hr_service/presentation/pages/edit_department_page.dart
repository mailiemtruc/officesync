import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/config/app_colors.dart';
import '../../data/models/department_model.dart';
import '../../data/models/employee_model.dart';
import '../../domain/repositories/department_repository.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import 'select_manager_page.dart';
// [QUAN TRỌNG] Import trang Details để điều hướng
import 'department_details_page.dart';

class EditDepartmentPage extends StatefulWidget {
  final DepartmentModel department;
  const EditDepartmentPage({super.key, required this.department});

  @override
  State<EditDepartmentPage> createState() => _EditDepartmentPageState();
}

class _EditDepartmentPageState extends State<EditDepartmentPage> {
  late TextEditingController _nameController;
  EmployeeModel? _selectedManager;
  bool _isLoading = false;

  // List này chứa TẤT CẢ nhân viên trong công ty (Vẫn giữ để hiển thị face pile ở dưới)
  List<EmployeeModel> _availableEmployees = [];
  // List này chỉ chứa thành viên thuộc phòng ban này
  List<EmployeeModel> _departmentMembers = [];

  late final DepartmentRepository _deptRepo;
  late final EmployeeRepositoryImpl _empRepo;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.department.name);
    _selectedManager = widget.department.manager;

    _deptRepo = DepartmentRepository(
      remoteDataSource: DepartmentRemoteDataSource(),
    );
    _empRepo = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _fetchData();
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return AppColors.primary;
    try {
      final buffer = StringBuffer();
      if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return AppColors.primary;
    }
  }

  Future<void> _fetchData() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      String currentUserId = "0";
      if (userInfoStr != null) {
        final userMap = jsonDecode(userInfoStr);
        currentUserId = userMap['id'].toString();
      }

      final allEmps = await _empRepo.getEmployees(currentUserId);

      if (mounted) {
        setState(() {
          _availableEmployees = allEmps;
          // Lọc thành viên
          _departmentMembers = allEmps.where((e) {
            final deptName = e.departmentName ?? "";
            // So sánh tên phòng ban
            return deptName.trim().toLowerCase() ==
                    widget.department.name.trim().toLowerCase() &&
                e.id != _selectedManager?.id;
          }).toList();
        });
      }
    } catch (e) {
      print("Error fetching employees: $e");
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final success = await _deptRepo.updateDepartment(
        widget.department.id!,
        _nameController.text.trim(),
        "Updated Description",
        _selectedManager?.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    try {
      await _deptRepo.deleteDepartment(widget.department.id!);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context, true); // Close page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // [ĐÃ SỬA] Hàm này được cập nhật để gọi SelectManagerPage mới (Server-side)
  Future<void> _pickManager() async {
    // Không cần lọc candidates cục bộ nữa, SelectManagerPage tự gọi API
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectManagerPage(
          selectedId: _selectedManager?.id,
          // availableEmployees: candidates, // <-- XÓA DÒNG NÀY (Nguyên nhân lỗi)
        ),
      ),
    );

    if (result != null && result is EmployeeModel) {
      setState(() {
        _selectedManager = result;
        bool removed = false;
        _departmentMembers.removeWhere((m) {
          if (m.id == result.id) {
            removed = true;
            return true;
          }
          return false;
        });
        if (removed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee moved from Member to Manager position.'),
            ),
          );
        }
      });
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Delete this department?',
        message:
            'This action cannot be undone. Employees in this department will be moved to "Unassigned".',
        confirmText: 'Delete',
        confirmColor: const Color(0xFFDC2626),
        onConfirm: _handleDelete,
      ),
    );
  }

  BoxDecoration _buildBlockDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFECF1FF)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color deptColor = _parseColor(widget.department.color);

    final int totalCount =
        (_selectedManager != null ? 1 : 0) + _departmentMembers.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                              color: AppColors.primary,
                              size: 24,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                'UPDATE DEPARTMENT',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Icon Department (Dùng deptColor)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: deptColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          PhosphorIcons.buildings(PhosphorIconsStyle.regular),
                          size: 56,
                          color: deptColor,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name Field
                      TextField(
                        controller: _nameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                          color: Colors.black,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Enter Department Name",
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CODE: ${widget.department.code ?? "N/A"}',
                        style: const TextStyle(
                          color: Color(0xFF6A6A6A),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Direct Manager
                      _buildSectionTitle('DIRECT MANAGER'),
                      const SizedBox(height: 12),
                      _buildDirectManagerCard(),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '*Approves requests and assigns tasks to department staff.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Overview
                      _buildSectionTitle('OVERVIEW'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: _buildBlockDecoration(),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Employees',
                                  style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Text(
                                  '$totalCount',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                            ),

                            // Nhấn vào Members -> Chuyển sang Details
                            InkWell(
                              onTap: () {
                                // Điều hướng sang DepartmentDetailsPage
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DepartmentDetailsPage(
                                      department: widget.department,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  const Text(
                                    'Members',
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const Spacer(),
                                  _buildMemberFacePile(),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Settings
                      _buildSectionTitle('SETTINGS'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: _buildBlockDecoration(),
                        child: InkWell(
                          onTap: () => _showDeleteDialog(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF2F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    PhosphorIcons.trash(
                                      PhosphorIconsStyle.regular,
                                    ),
                                    color: const Color(0xFFDC2626),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Delete Department',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Delete this department from the system',
                                        style: TextStyle(
                                          color: Color(0xFFF87171),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberFacePile() {
    if (_departmentMembers.isEmpty) {
      return const Text(
        "No members",
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    final displayMembers = _departmentMembers.take(4).toList();
    final remainingCount = _departmentMembers.length - 4;

    return SizedBox(
      height: 35,
      width:
          (displayMembers.length * 22.0) + (remainingCount > 0 ? 35.0 : 0) + 10,
      child: Stack(
        children: [
          ...List.generate(displayMembers.length, (index) {
            final emp = displayMembers[index];
            return Positioned(
              left: index * 22.0,
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  // Placeholder màu xám nhạt
                  color: Colors.grey[200],
                ),
                child: ClipOval(
                  child: (emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty)
                      ? Image.network(
                          emp.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(Icons.person, size: 20, color: Colors.grey),
                ),
              ),
            );
          }),
          if (remainingCount > 0)
            Positioned(
              left: 4 * 22.0,
              child: Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B5563),
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDirectManagerCard() {
    final String managerName =
        _selectedManager?.fullName ?? "No Manager Assigned";
    final String? avatarUrl = _selectedManager?.avatarUrl;

    return InkWell(
      onTap: _pickManager,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E7FF)),
        ),
        child: Row(
          children: [
            ClipOval(
              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? Image.network(
                      avatarUrl,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 46,
                        height: 46,
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Container(
                      width: 46,
                      height: 46,
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    managerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to Change',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Icon(
                    PhosphorIcons.arrowsDownUp(PhosphorIconsStyle.regular),
                    size: 20,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
