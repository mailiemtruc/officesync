import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import '../../widgets/selection_bottom_sheet.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../domain/repositories/employee_repository.dart';

class EditProfileEmployeePage extends StatefulWidget {
  final EmployeeModel employee;
  const EditProfileEmployeePage({super.key, required this.employee});

  @override
  State<EditProfileEmployeePage> createState() =>
      _EditProfileEmployeePageState();
}

class _EditProfileEmployeePageState extends State<EditProfileEmployeePage> {
  // Biến trạng thái
  bool _isActive = true;
  String _selectedRole = 'Staff';
  String _selectedDepartmentName = 'Loading...';

  // [MỚI] Biến kiểm tra quyền hạn người đang đăng nhập
  bool _isCurrentUserManager = false;
  String? _currentUserId; // [QUAN TRỌNG] Lưu ID người đang thao tác
  final _storage = const FlutterSecureStorage();

  DepartmentModel? _selectedDepartmentObj;
  late TextEditingController _emailController;
  late final EmployeeRepository _repository;
  bool _isLoading = false;

  List<DepartmentModel> _realDepartments = [];

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _emailController = TextEditingController(text: widget.employee.email);
    _isActive = (widget.employee.status == "ACTIVE");

    String roleApi = widget.employee.role;
    try {
      if (roleApi.toUpperCase() == 'MANAGER') {
        _selectedRole = 'Manager';
      } else {
        _selectedRole = 'Staff';
      }
    } catch (e) {
      _selectedRole = "Staff";
    }

    _selectedDepartmentName = widget.employee.departmentName ?? "Unassigned";

    // [SỬA] Gọi hàm khởi tạo tuần tự để tránh lỗi thiếu ID
    _initData();
  }

  // [LOGIC MỚI] Hàm khởi tạo tuần tự
  Future<void> _initData() async {
    await _checkCurrentUserRole(); // 1. Lấy ID trước
    if (_currentUserId != null) {
      await _fetchDepartments(); // 2. Sau đó mới lấy phòng ban
    }
  }

  Future<void> _checkCurrentUserRole() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final data = jsonDecode(userInfoStr);
        setState(() {
          _currentUserId = data['id'].toString(); // Lưu ID
        });

        String role = data['role'] ?? 'STAFF';
        if (role.toUpperCase() == 'MANAGER') {
          setState(() {
            _isCurrentUserManager = true;
          });
        }
      }
    } catch (e) {
      print("Error checking user role: $e");
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      if (_currentUserId == null) return;

      // [SỬA] Truyền _currentUserId vào API getDepartments
      final depts = await _repository.getDepartments(_currentUserId!);

      if (mounted) {
        setState(() {
          _realDepartments = depts;
          if (_selectedDepartmentName != "Unassigned") {
            try {
              _selectedDepartmentObj = _realDepartments.firstWhere(
                (d) => d.name == _selectedDepartmentName,
              );
            } catch (_) {
              _selectedDepartmentName = "Unassigned";
              _selectedDepartmentObj = null;
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching departments: $e");
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // --- LOGIC UI BOTTOM SHEET SELECTOR ---
  void _showDepartmentSelector() {
    if (_isCurrentUserManager) return;

    if (_realDepartments.isEmpty) return;

    final items = _realDepartments
        .map(
          (d) => {'id': d.id.toString(), 'title': d.name, 'desc': d.code ?? ''},
        )
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SelectionBottomSheet(
        title: 'Select Department',
        items: items,
        selectedId: _selectedDepartmentObj?.id.toString(),
        onSelected: (idStr) {
          final selected = _realDepartments.firstWhere(
            (d) => d.id.toString() == idStr,
          );
          setState(() {
            _selectedDepartmentObj = selected;
            _selectedDepartmentName = selected.name;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRoleSelector() {
    if (_isCurrentUserManager) return;

    final items = [
      {'id': 'Staff', 'title': 'Staff', 'desc': 'Standard access'},
      {'id': 'Manager', 'title': 'Manager', 'desc': 'Department lead'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SelectionBottomSheet(
        title: 'Assign Role',
        items: items,
        selectedId: _selectedRole,
        onSelected: (id) {
          setState(() => _selectedRole = id);
          Navigator.pop(context);
        },
      ),
    );
  }

  // --- LOGIC XỬ LÝ LƯU ---
  Future<void> _handleSave() async {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      _showErrorSnackBar('Invalid email format.');
      return;
    }

    if (_selectedRole == 'Manager' && _selectedDepartmentObj != null) {
      if (_selectedDepartmentObj!.manager != null) {
        final currentManagerId = _selectedDepartmentObj!.manager!.id;
        final myId = widget.employee.id;
        if (currentManagerId.toString() != myId.toString()) {
          final currentManagerName =
              _selectedDepartmentObj!.manager?.fullName ?? "Unknown";
          _showErrorSnackBar(
            'Department "${_selectedDepartmentName}" already has a Manager ($currentManagerName).',
          );
          return;
        }
      }
    }

    if (_currentUserId == null) {
      _showErrorSnackBar('Session expired. Please login again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      String statusToSend = _isActive ? "ACTIVE" : "LOCKED";
      String roleToSend = _selectedRole.toUpperCase();
      int? deptIdToSend = _selectedDepartmentObj?.id;

      // [SỬA] Truyền _currentUserId vào hàm updateEmployee
      final success = await _repository.updateEmployee(
        _currentUserId!,
        widget.employee.id!,
        widget.employee.fullName,
        widget.employee.phone,
        widget.employee.dateOfBirth,
        email: email,
        avatarUrl: widget.employee.avatarUrl,
        status: statusToSend,
        role: roleToSend,
        departmentId: deptIdToSend,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          // [ĐÃ SỬA]
          CustomSnackBar.show(
            context,
            title: 'Success',
            message: 'Profile updated successfully!',
            isError: false,
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString().replaceAll("Exception: ", "");
        _showErrorSnackBar(errorMsg);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    // [ĐÃ SỬA]
    CustomSnackBar.show(
      context,
      title: 'Error',
      message: message,
      isError: true,
    );
  }

  // --- DELETE & SUSPEND ---
  void _showDeleteConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Delete this account?',
        message: 'This action cannot be undone.',
        confirmText: 'Delete',
        confirmColor: const Color(0xFFDC2626),
        onConfirm: () async {
          Navigator.pop(context);

          // [FIX LỖI] Kiểm tra user id hiện tại
          if (_currentUserId == null) {
            _showErrorSnackBar("Session error. Please login again.");
            return;
          }

          setState(() => _isLoading = true);

          // [FIX LỖI] Truyền 2 tham số: (deleterId, targetId)
          bool success = await _repository.deleteEmployee(
            _currentUserId!, // Người xóa (bạn)
            widget.employee.id!, // Người bị xóa
          );

          if (mounted) {
            setState(() => _isLoading = false);
            if (success) {
              Navigator.pop(context, true);
              // [ĐÃ SỬA]
              CustomSnackBar.show(
                context,
                title: 'Deleted',
                message: 'Employee deleted successfully',
                isError: false,
              );
            } else {
              _showErrorSnackBar("Failed to delete employee");
            }
          }
        },
      ),
    );
  }

  void _showSuspendConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConfirmBottomSheet(
        title: 'Suspend Access?',
        message: 'Employee will not be able to log in.',
        confirmText: 'Suspend',
        confirmColor: const Color(0xFFF97316),
        onConfirm: () {
          setState(() => _isActive = false);
          Navigator.pop(context);
        },
        onCancel: () {
          setState(() => _isActive = true);
        },
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
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
                            'EDIT EMPLOYEE',
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
                  const SizedBox(height: 24),

                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      color: Colors.grey[200],
                    ),
                    child: ClipOval(
                      child:
                          (widget.employee.avatarUrl != null &&
                              widget.employee.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              widget.employee.avatarUrl!,
                              fit: BoxFit.cover,
                              // [SỬA 1]
                              errorBuilder: (_, __, ___) => Icon(
                                PhosphorIcons.user(PhosphorIconsStyle.fill),
                                size: 60,
                                color: Colors.grey,
                              ),
                            )
                          // [SỬA 2]
                          : Icon(
                              PhosphorIcons.user(PhosphorIconsStyle.fill),
                              size: 60,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.employee.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EMPLOYEE ID: ${widget.employee.employeeCode ?? "N/A"}',
                    style: const TextStyle(
                      color: Color(0xFF6A6A6A),
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionTitle('ACCOUNT SETTINGS'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: _buildBlockDecoration(),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.envelopeSimple(),
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                decoration: const InputDecoration(
                                  labelText: "Email",
                                  labelStyle: TextStyle(
                                    color: Color(0xFF0C28B3),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFFA16207),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Contact Admin to change email credentials.",
                                  style: TextStyle(
                                    color: Color(0xFFA16207),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('ROLES & PERMISSIONS'),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: _buildBlockDecoration(),
                    child: Column(
                      children: [
                        _buildSelectorRow(
                          label: 'Department',
                          value: _selectedDepartmentName,
                          onTap: _isCurrentUserManager
                              ? null
                              : _showDepartmentSelector,
                          isReadOnly: _isCurrentUserManager,
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        _buildSelectorRow(
                          label: 'Role',
                          value: _selectedRole,
                          onTap: _isCurrentUserManager
                              ? null
                              : _showRoleSelector,
                          isBlueValue: !_isCurrentUserManager,
                          isReadOnly: _isCurrentUserManager,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('STATUS'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _buildBlockDecoration(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Switch.adaptive(
                          value: _isActive,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (value) {
                            if (value == false) {
                              _showSuspendConfirmation(context);
                            } else {
                              setState(() => _isActive = true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => _showDeleteConfirmation(context),
                    child: const Text(
                      'Delete account',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
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
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF655F5F),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSelectorRow({
    required String label,
    required String value,
    required VoidCallback? onTap,
    bool isBlueValue = false,
    bool isReadOnly = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xE5706060),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isReadOnly
                        ? Colors.grey[700]
                        : (isBlueValue ? AppColors.primary : Colors.black),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isReadOnly
                      ? PhosphorIcons.lock(PhosphorIconsStyle.regular)
                      : Icons.chevron_right,
                  color: const Color(0xFFBDC6DE),
                  size: isReadOnly ? 18 : 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
