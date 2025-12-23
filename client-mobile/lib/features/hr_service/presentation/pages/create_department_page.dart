import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- IMPORTS ---
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../domain/repositories/department_repository.dart';

// Import Employee Repository
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';

// Import các trang chọn
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

  // [ĐÃ SỬA] Đổi tên biến này thành _availableEmployees để khớp với logic bên dưới
  List<EmployeeModel> _availableEmployees = [];

  late final DepartmentRepository _departmentRepository;
  late final EmployeeRepository _employeeRepository;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _departmentRepository = DepartmentRepository(
      remoteDataSource: DepartmentRemoteDataSource(),
    );

    _employeeRepository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _fetchAllEmployees();
  }

  Future<void> _fetchAllEmployees() async {
    try {
      String? currentUserId = await _getCurrentUserId();
      if (currentUserId != null) {
        final emps = await _employeeRepository.getEmployees(currentUserId);
        if (mounted) {
          setState(() {
            // [ĐÃ SỬA] Cập nhật vào biến đúng
            _availableEmployees = emps;
          });
        }
      }
    } catch (e) {
      print("Error fetching employees: $e");
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter department name'),
          backgroundColor: Colors.red,
        ),
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
      );

      final success = await _departmentRepository.createDepartment(
        newDept,
        currentUserId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC CHỌN QUẢN LÝ ---
  Future<void> _pickManager() async {
    // 1. Lọc danh sách ứng viên làm Manager
    // [ĐÃ KHỚP] Biến _availableEmployees giờ đã được khai báo đúng
    final candidates = _availableEmployees.where((e) {
      // RULE 1: Không phải Admin
      bool isNotAdmin = e.role != 'COMPANY_ADMIN';
      // RULE 2: Phải đang hoạt động
      bool isActive = e.status == 'ACTIVE';

      return isNotAdmin && isActive;
    }).toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectManagerPage(
          selectedId: _selectedManager?.id,
          availableEmployees: candidates,
        ),
      ),
    );

    if (result != null && result is EmployeeModel) {
      setState(() {
        _selectedManager = result;

        // [QUAN TRỌNG] Logic loại trừ lẫn nhau (Mutual Exclusion)
        if (_selectedMembers.any((m) => m.id == result.id)) {
          _selectedMembers.removeWhere((m) => m.id == result.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result.fullName} has been removed from members list to be Manager.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }
  }

  // --- LOGIC CHỌN THÀNH VIÊN ---
  Future<void> _pickMembers() async {
    final candidates = _availableEmployees.where((e) {
      bool isNotAdmin = e.role != 'COMPANY_ADMIN';
      bool isActive = e.status == 'ACTIVE';

      // [QUAN TRỌNG] Không được hiện người đang được chọn làm Manager
      bool isNotSelectedManager = true;
      if (_selectedManager != null) {
        isNotSelectedManager = e.id != _selectedManager!.id;
      }

      return isNotAdmin && isActive && isNotSelectedManager;
    }).toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          alreadySelectedMembers: _selectedMembers,
          availableEmployees: candidates,
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      // Avatar Department
                      Center(
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD8DEEC),
                              width: 2,
                            ),
                            color: const Color(0xFFE2E8F0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                            size: 60,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

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
                              if (_selectedManager == null) ...[
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'Select Manager',
                                  style: TextStyle(
                                    color: Color(0xFF9B9292),
                                    fontSize: 16,
                                  ),
                                ),
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
                                            errorBuilder: (ctx, err, stack) =>
                                                const Icon(
                                                  Icons.person,
                                                  color: AppColors.primary,
                                                ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: AppColors.primary,
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
                                      ),
                                      Text(
                                        'Code: ${_selectedManager!.employeeCode ?? "N/A"}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const Spacer(),
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
