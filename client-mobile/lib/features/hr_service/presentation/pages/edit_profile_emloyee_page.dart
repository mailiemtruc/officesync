import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart'; // [MỚI] Import model
import '../../widgets/confirm_bottom_sheet.dart';

// [MỚI] Import để gọi API
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';

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

  late TextEditingController _emailController;
  late final EmployeeRepositoryImpl _repository;
  bool _isLoading = false;

  // List vai trò hiển thị UI
  final List<String> _roles = ['Manager', 'Staff', 'Company_Admin'];

  // [DATA THẬT] List phòng ban từ API
  List<DepartmentModel> _realDepartments = [];
  List<String> _deptNames = []; // Dùng để hiển thị lên Dropdown

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    // 1. Fill dữ liệu từ widget.employee vào state
    _emailController = TextEditingController(text: widget.employee.email);
    _isActive = (widget.employee.status == "ACTIVE");

    // Mapping Role (Từ API uppercase sang Title case UI)
    String roleApi = widget.employee.role;
    try {
      // Tìm role tương ứng trong list UI (không phân biệt hoa thường)
      var foundRole = _roles.firstWhere(
        (r) => r.toUpperCase() == roleApi.toUpperCase(),
        orElse: () => "Staff",
      );
      _selectedRole = foundRole;
    } catch (e) {
      _selectedRole = "Staff";
    }

    // Mapping Department Name ban đầu
    _selectedDepartmentName = widget.employee.departmentName ?? "Unassigned";
    _deptNames = [_selectedDepartmentName]; // Init tạm để không lỗi UI

    // 2. Tải danh sách phòng ban thật để lấy ID
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final depts = await _repository.getDepartments();
      if (mounted) {
        setState(() {
          _realDepartments = depts;
          _deptNames = depts.map((d) => d.name).toList();

          // Logic chọn lại giá trị dropdown sau khi load xong list
          if (!_deptNames.contains(_selectedDepartmentName)) {
            if (_deptNames.isNotEmpty) {
              _selectedDepartmentName = _deptNames.first;
            } else {
              _deptNames.add("Unassigned");
              _selectedDepartmentName = "Unassigned";
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

  // --- LOGIC XỬ LÝ LƯU (THẬT) ---
  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    try {
      // 1. Map tên phòng ban sang ID
      int? deptIdToSend;
      try {
        if (_realDepartments.isNotEmpty) {
          final selectedDept = _realDepartments.firstWhere(
            (d) => d.name == _selectedDepartmentName,
          );
          deptIdToSend = selectedDept.id;
        }
      } catch (e) {
        print("Cannot find ID for dept: $_selectedDepartmentName");
      }

      // 2. Chuẩn bị dữ liệu gửi (Status & Role UpperCase)
      String statusToSend = _isActive ? "ACTIVE" : "LOCKED";
      String roleToSend = _selectedRole.toUpperCase();

      // 3. Gọi API Update
      final success = await _repository.updateEmployee(
        widget.employee.id!,
        widget.employee.fullName,
        widget.employee.phone,
        widget.employee.dateOfBirth,
        email: _emailController.text, // [MỚI] Gửi email từ controller
        avatarUrl: widget.employee.avatarUrl,
        status: statusToSend,
        role: roleToSend,
        departmentId: deptIdToSend,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated successfully!")),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Hiển thị lỗi từ Backend (ví dụ: Email already exists)
        // Cắt chuỗi "Exception: " đi cho đẹp nếu muốn
        String errorMsg = e.toString().replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- LOGIC XÓA (THẬT) ---
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
          Navigator.pop(context); // Đóng dialog

          setState(() => _isLoading = true);
          // Gọi API Xóa
          bool success = await _repository.deleteEmployee(widget.employee.id!);

          if (mounted) {
            setState(() => _isLoading = false);
            if (success) {
              Navigator.pop(context, true); // Đóng trang edit về list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Employee deleted successfully")),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Failed to delete employee")),
              );
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
                  // 1. Header
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

                  // 2. Avatar Circle
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
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
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Name & ID
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

                  // 4. Form Fields
                  _buildSectionTitle('ACCOUNT SETTINGS'),
                  const SizedBox(height: 12),

                  // Email Field
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
                            color: const Color(0xFFFEFFD2),
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

                  // Roles & Dept
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: _buildBlockDecoration(),
                    child: Column(
                      children: [
                        _buildDropdownRow(
                          label: 'Department',
                          value: _selectedDepartmentName,
                          items: _deptNames,
                          onChanged: (val) =>
                              setState(() => _selectedDepartmentName = val!),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildDropdownRow(
                          label: 'Role',
                          value: _selectedRole,
                          items: _roles,
                          onChanged: (val) =>
                              setState(() => _selectedRole = val!),
                          isBlueValue: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('STATUS'),
                  const SizedBox(height: 12),

                  // Status Container
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

  // Helper Widgets
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

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isBlueValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.chevron_right, color: Colors.grey),
              style: TextStyle(
                color: isBlueValue ? AppColors.primary : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
