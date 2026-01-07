import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../domain/repositories/department_repository_impl.dart';
import '../../domain/repositories/department_repository.dart';
// [QUAN TRỌNG] Các trang chọn
import 'select_manager_page.dart';
import 'add_members_page.dart';

class CreateDepartmentPage extends StatefulWidget {
  const CreateDepartmentPage({super.key});

  @override
  State<CreateDepartmentPage> createState() => _CreateDepartmentPageState();
}

class _CreateDepartmentPageState extends State<CreateDepartmentPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  // Biến state
  EmployeeModel? _selectedManager;
  List<EmployeeModel> _selectedMembers = [];
  bool _isLoading = false;
  bool _isHr = false; // [MỚI]
  late final DepartmentRepository _departmentRepository;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _departmentRepository = DepartmentRepositoryImpl(
      remoteDataSource: DepartmentRemoteDataSource(),
    );
    // [ĐÃ XÓA] Không gọi _fetchAllEmployees() nữa vì dùng Server-side search
  }

  Future<String?> _getCurrentUserId() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return userMap['id'].toString();
      }
    } catch (e) {
      print("Error reading user info: $e");
    }
    return null;
  }

  Future<void> _handleCreateDepartment() async {
    if (_nameController.text.isEmpty) {
      // [ĐÃ SỬA]
      CustomSnackBar.show(
        context,
        title: 'Validation Error',
        message: 'Please enter department name',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        throw Exception("Session expired. Please login again.");
      }

      List<String> memberIds = _selectedMembers.map((e) => e.id!).toList();

      final newDept = DepartmentModel(
        id: null,
        name: _nameController.text.trim(),
        manager: _selectedManager,
        memberIds: memberIds,
        isHr: _isHr,
      );

      final success = await _departmentRepository.createDepartment(
        newDept,
        currentUserId,
      );

      if (success && mounted) {
        // [ĐÃ SỬA]
        CustomSnackBar.show(
          context,
          title: 'Success',
          message: 'Department created successfully!',
          isError: false,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // [ĐÃ SỬA]
        CustomSnackBar.show(
          context,
          title: 'Error',
          message: 'Error: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC CHỌN QUẢN LÝ ---
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
        _selectedManager = result;

        if (_selectedMembers.any((m) => m.id == result.id)) {
          _selectedMembers.removeWhere((m) => m.id == result.id);
          // [ĐÃ SỬA]
          CustomSnackBar.show(
            context,
            title: 'Member Removed',
            message:
                '${result.fullName} has been removed from members list to be Manager.',
            isError: false,
          );
        }
      });
    }
  }

  // --- LOGIC CHỌN THÀNH VIÊN ---
  Future<void> _pickMembers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          alreadySelectedMembers: _selectedMembers,
          // [MỚI] Truyền ID Manager vào để trang AddMembers lọc ra (không hiện Manager để chọn nữa)
          excludeManagerId: _selectedManager?.id,
        ),
      ),
    );

    if (result != null && result is List<EmployeeModel>) {
      setState(() {
        _selectedMembers = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          SafeArea(
            // [SỬA 1] Đổi Center -> Align(topCenter) để đẩy nội dung lên trên cùng
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  // [SỬA 2] Bỏ padding top (24 -> 0) để kiểm soát bằng SizedBox
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [SỬA 3] Thêm khoảng cách chuẩn 20px từ đỉnh an toàn
                      const SizedBox(height: 20),

                      // --- HEADER ---
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
                                'CREATE DEPARTMENT',
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

                      // [ĐÃ SỬA] Avatar Department đồng bộ màu với AddEmployeePage
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            // [ĐỒNG BỘ 1] Viền màu xám đậm hơn (grey[300])
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),

                            // [ĐỒNG BỘ 2] Nền màu xám nhạt (grey[200])
                            color: Colors.grey[200],

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(
                                  0,
                                  4,
                                ), // Chỉnh offset 0,4 cho khớp chuẩn
                              ),
                            ],
                          ),
                          child: Icon(
                            PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                            size: 60,
                            // [ĐỒNG BỘ 3] Màu icon xám (grey[400])
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ... (Phần dưới giữ nguyên không đổi) ...
                      _buildSectionTitle('BASIC INFORMATION'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: _buildBlockDecoration(),
                        child: Column(
                          children: [
                            _buildTextField(
                              label: 'Department Name',
                              hint: 'e.g. Marketing',
                              controller: _nameController,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              label: 'Dept Code',
                              hint: 'Auto (DEP-XXX)',
                              controller: _codeController,
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('LEADERSHIP'),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickManager,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _buildBlockDecoration(),
                          child: Row(
                            children: [
                              // --- TRƯỜNG HỢP 1: CHƯA CHỌN MANAGER ---
                              if (_selectedManager == null) ...[
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  // [ĐÃ SỬA] Dùng Phosphor Icon
                                  child: Icon(
                                    PhosphorIcons.user(PhosphorIconsStyle.fill),
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                const Expanded(
                                  child: Text(
                                    'Select Manager',
                                    style: TextStyle(
                                      color: Color(0xFF9B9292),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),

                                // --- TRƯỜNG HỢP 2: ĐÃ CHỌN MANAGER ---
                              ] else ...[
                                ClipOval(
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    color: AppColors.primary.withOpacity(0.1),
                                    child:
                                        (_selectedManager!.avatarUrl != null &&
                                            _selectedManager!
                                                .avatarUrl!
                                                .isNotEmpty)
                                        ? Image.network(
                                            _selectedManager!.avatarUrl!,
                                            fit: BoxFit.cover,
                                            // [ĐÃ SỬA] Icon lỗi tải ảnh
                                            errorBuilder: (ctx, err, stack) =>
                                                Icon(
                                                  PhosphorIcons.user(
                                                    PhosphorIconsStyle.fill,
                                                  ),
                                                  color: AppColors.primary,
                                                  size: 24,
                                                ),
                                          )
                                        // [ĐÃ SỬA] Icon mặc định khi không có ảnh
                                        : Icon(
                                            PhosphorIcons.user(
                                              PhosphorIconsStyle.fill,
                                            ),
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedManager!.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Employee Code: ${_selectedManager!.employeeCode ?? "N/A"}',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(0xFFBDC6DE),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // [MỚI] PHẦN UI CẤU HÌNH HR
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
                      _buildSectionTitle('INITIAL MEMBERS'),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickMembers,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _buildBlockDecoration(),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.plus(PhosphorIconsStyle.bold),
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Add Members',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedMembers.isEmpty
                                          ? 'Select from existing list'
                                          : '${_selectedMembers.length} members selected',
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(0xFFBDC6DE),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : _handleCreateDepartment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 4,
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
                                  'Create Department',
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF655F5F),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
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

  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    bool enabled = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: enabled ? Colors.black : const Color(0xFFBDC6DE),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFBDC6DE),
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
