import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/department_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import 'select_manager_page.dart';
import 'add_members_page.dart';
import '../../domain/repositories/department_repository_impl.dart';
import '../../domain/repositories/department_repository.dart';
import '../../../../core/utils/custom_snackbar.dart';

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
  bool _isHr = false;
  late String _initialName;
  late bool _initialIsHr;
  EmployeeModel? _initialManager;
  // Biến lưu danh sách thành viên hiện tại (Đang chỉnh sửa)
  List<EmployeeModel> _departmentMembers = [];
  // Biến lưu danh sách ban đầu để so sánh sự thay đổi khi bấm Save
  List<EmployeeModel> _initialMembers = [];

  late final DepartmentRepository _deptRepo;
  late final EmployeeRepository _empRepo;
  final _storage = const FlutterSecureStorage();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _isHr = widget.department.isHr;
    _nameController = TextEditingController(text: widget.department.name);
    _selectedManager = widget.department.manager;

    _initialName = widget.department.name;
    _initialIsHr = widget.department.isHr;
    _initialManager = widget.department.manager;

    _deptRepo = DepartmentRepositoryImpl(
      remoteDataSource: DepartmentRemoteDataSource(),
    );
    _empRepo = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _fetchData();
  }

  bool _hasMemberChanges() {
    if (_departmentMembers.length != _initialMembers.length) return true;

    final oldIds = _initialMembers.map((e) => e.id).toSet();
    final newIds = _departmentMembers.map((e) => e.id).toSet();

    // Nếu set mới không chứa đủ các ID cũ (hoặc ngược lại) nghĩa là có thay đổi
    return !oldIds.containsAll(newIds);
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
      String currentUserIdForEmp = "0";

      if (userInfoStr != null) {
        final userMap = jsonDecode(userInfoStr);
        currentUserIdForEmp = userMap['id'].toString();
        setState(() {
          _currentUserId = currentUserIdForEmp;
        });
      }

      final allEmps = await _empRepo.getEmployees(currentUserIdForEmp);

      if (mounted) {
        setState(() {
          // Lọc ra các thành viên thuộc phòng ban này (trừ Manager)
          _departmentMembers = allEmps.where((e) {
            final deptName = e.departmentName ?? "";
            return deptName.trim().toLowerCase() ==
                    widget.department.name.trim().toLowerCase() &&
                e.id != _selectedManager?.id;
          }).toList();

          //  Sao chép danh sách ban đầu để đối chiếu sau này
          _initialMembers = List.from(_departmentMembers);
        });
      }
    } catch (e) {
      print("Error fetching employees: $e");
    }
  }

  //  Hàm mở trang chọn thành viên (Thay vì mở trang chi tiết)
  Future<void> _openSelectMembers() async {
    final List<EmployeeModel>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          alreadySelectedMembers:
              _departmentMembers, // Truyền danh sách hiện tại
          excludeManagerId: _selectedManager?.id, // Loại trừ ông quản lý ra
        ),
      ),
    );

    // Khi quay lại, chỉ cập nhật biến cục bộ, CHƯA gọi API
    if (result != null) {
      setState(() {
        _departmentMembers = result;
      });
      // Thông báo nhẹ để người dùng biết đã cập nhật tạm thời
      CustomSnackBar.show(
        context,
        title: 'Draft Updated',
        message: 'Member list updated. Tap "Save Changes" to commit.',
        isError: false,
      );
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty) return;

    // [CHECK THAY ĐỔI]
    final bool nameChanged = _nameController.text.trim() != _initialName;
    final bool hrChanged = _isHr != _initialIsHr;

    // So sánh Manager (xử lý null safety)
    final String oldManagerId = _initialManager?.id ?? "";
    final String newManagerId = _selectedManager?.id ?? "";
    final bool managerChanged = oldManagerId != newManagerId;

    // So sánh danh sách thành viên
    final bool membersChanged = _hasMemberChanges();

    if (!nameChanged && !hrChanged && !managerChanged && !membersChanged) {
      CustomSnackBar.show(
        context,
        title: 'Info',
        message: 'No changes detected.',
        isError: false,
        backgroundColor: const Color(0xFF6B7280),
      );
      return;
    }

    if (_currentUserId == null) {
      CustomSnackBar.show(
        context,
        title: 'Authentication',
        message: 'Session expired. Please login again.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Cập nhật thông tin Phòng ban
      final success = await _deptRepo.updateDepartment(
        _currentUserId!,
        widget.department.id!,
        _nameController.text.trim(),
        _selectedManager?.id,
        _isHr,
      );

      // 2. Cập nhật danh sách thành viên (Logic thông minh giữ nguyên từ trước)
      final addedMembers = _departmentMembers
          .where(
            (newItem) =>
                !_initialMembers.any((oldItem) => oldItem.id == newItem.id) &&
                newItem.id != _selectedManager?.id,
          )
          .toList();

      final removedMembers = _initialMembers
          .where(
            (oldItem) =>
                !_departmentMembers.any(
                  (newItem) => newItem.id == oldItem.id,
                ) &&
                oldItem.id != _selectedManager?.id,
          )
          .toList();

      // a. Gán phòng ban cho người mới
      for (var emp in addedMembers) {
        if (emp.id != null) {
          String roleToSend = emp.role;
          if (emp.role == 'MANAGER') roleToSend = 'STAFF'; // Hạ chức nếu cần

          await _empRepo.updateEmployee(
            _currentUserId!,
            emp.id!,
            emp.fullName,
            emp.phone,
            emp.dateOfBirth,
            role: roleToSend,
            departmentId: widget.department.id,
          );
        }
      }

      // b. Gỡ phòng ban cho người bị xóa
      for (var emp in removedMembers) {
        if (emp.id != null) {
          await _empRepo.updateEmployee(
            _currentUserId!,
            emp.id!,
            emp.fullName,
            emp.phone,
            emp.dateOfBirth,
            role: emp.role,
            departmentId: 0, // Unassigned
          );
        }
      }

      if (success && mounted) {
        CustomSnackBar.show(
          context,
          title: 'Success',
          message: 'Updated successfully!',
          isError: false,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        CustomSnackBar.show(
          context,
          title: 'Error',
          message: msg,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    if (_currentUserId == null) return;

    setState(() => _isLoading = true);
    try {
      await _deptRepo.deleteDepartment(_currentUserId!, widget.department.id!);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context, true); // Close page
        CustomSnackBar.show(
          context,
          title: 'Success',
          message: 'Department deleted',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        String msg = e.toString().replaceAll("Exception: ", "");
        CustomSnackBar.show(
          context,
          title: 'Delete Failed',
          message: 'Delete failed: $msg',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickManager() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SelectManagerPage(selectedId: _selectedManager?.id),
      ),
    );

    if (result != null && result is EmployeeModel) {
      setState(() {
        // 1. Lưu lại Manager cũ
        final oldManager = _selectedManager;
        final newManager = result;

        // Nếu chọn lại đúng người cũ thì không làm gì cả
        if (oldManager?.id == newManager.id) return;

        // 2. Cập nhật Manager mới
        _selectedManager = newManager;

        // 3. Xử lý Manager CŨ: Đưa xuống làm nhân viên
        if (oldManager != null) {
          // Kiểm tra để chắc chắn không bị trùng (dù logic ít khi trùng)
          final isAlreadyInList = _departmentMembers.any(
            (m) => m.id == oldManager.id,
          );

          if (!isAlreadyInList) {
            // Thêm vào danh sách thành viên
            _departmentMembers.add(oldManager);
          }
        }

        // 4. Xử lý Manager MỚI: Nếu vốn là nhân viên trong phòng thì xóa khỏi list member
        // (Vì giờ đã leo lên chức Manager rồi, không nằm trong list member nữa)
        bool promoted = false;
        _departmentMembers.removeWhere((m) {
          if (m.id == newManager.id) {
            promoted = true;
            return true;
          }
          return false;
        });

        // Hiển thị thông báo nhỏ nếu cần
        if (promoted) {
          CustomSnackBar.show(
            context,
            title: 'Info',
            message:
                'Member promoted to Manager. Old manager demoted to Member.',
            isError: false,
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                PhosphorIcons.caretLeft(
                                  PhosphorIconsStyle.bold,
                                ),
                                color: AppColors.primary,
                                size: 24,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),

                          const Expanded(
                            child: Text(
                              'UPDATE DEPARTMENT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 24,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            deptColor.withOpacity(0.15),
                            Colors.white,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: deptColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: deptColor.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          PhosphorIcons.buildings(PhosphorIconsStyle.duotone),
                          size: 60,
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

                            // Đổi InkWell này thành mở _openSelectMembers
                            InkWell(
                              onTap:
                                  _openSelectMembers, // Gọi hàm chọn thành viên nội bộ
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
                                  // Đổi icon thành bút chì hoặc cộng để gợi ý chỉnh sửa
                                  Icon(
                                    PhosphorIcons.pencilSimple(
                                      PhosphorIconsStyle.regular,
                                    ),
                                    size: 18,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('DEPARTMENT SETTINGS'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: _buildBlockDecoration(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Main HR Department',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This department receives all employee requests.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _isHr,
                              activeColor: AppColors.primary,
                              onChanged: (value) {
                                setState(() {
                                  _isHr = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
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
                  color: Colors.grey[200],
                ),
                child: ClipOval(
                  child: (emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty)
                      ? Image.network(
                          emp.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            size: 20,
                            color: Colors.grey,
                          ),
                        )
                      : Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.fill),
                          size: 20,
                          color: Colors.grey,
                        ),
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
                        child: Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.fill),
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : Container(
                      width: 46,
                      height: 46,
                      color: AppColors.primary.withOpacity(0.1),
                      child: Icon(
                        PhosphorIcons.user(PhosphorIconsStyle.fill),
                        color: AppColors.primary,
                      ),
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
