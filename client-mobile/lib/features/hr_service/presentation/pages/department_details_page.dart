import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/department_model.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';
import '../../widgets/skeleton_employee_card.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import 'add_members_page.dart';
import 'employee_profile_page.dart';
import '../../../../core/utils/custom_snackbar.dart';

class DepartmentDetailsPage extends StatefulWidget {
  final DepartmentModel department;

  const DepartmentDetailsPage({super.key, required this.department});

  @override
  State<DepartmentDetailsPage> createState() => _DepartmentDetailsPageState();
}

class _DepartmentDetailsPageState extends State<DepartmentDetailsPage> {
  List<EmployeeModel> _members = [];
  bool _isLoading = true;
  late final EmployeeRepository _employeeRepo;

  String? _currentUserId;
  String? _currentUserRole;

  final _storage = const FlutterSecureStorage();
  late DepartmentModel _currentDept;

  @override
  void initState() {
    super.initState();
    _employeeRepo = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );
    _currentDept = widget.department;
    _initData();
  }

  Future<void> _initData() async {
    await _loadCurrentUser();
    _fetchMembers();
  }

  Future<void> _loadCurrentUser() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final data = jsonDecode(userInfoStr);
        if (mounted) {
          setState(() {
            _currentUserId = data['id'].toString();
            _currentUserRole = data['role'];
          });
        }
      }
    } catch (e) {
      print("Error loading user: $e");
    }
  }

  Future<void> _fetchMembers() async {
    if (_currentDept.id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Lấy danh sách thành viên mới nhất từ API
      final deptMembers = await _employeeRepo.getEmployeesByDepartment(
        _currentDept.id!,
      );

      if (mounted) {
        setState(() {
          EmployeeModel? freshManager;

          // Thay vì so sánh ID cũ (có thể bị null),
          // tìm người có role là MANAGER trong danh sách vừa tải về.
          try {
            freshManager = deptMembers.firstWhere(
              (e) => e.role.toUpperCase() == 'MANAGER',
            );
          } catch (e) {
            // Nếu không tìm thấy ai là Manager trong list này
            // (Có thể phòng chưa có Manager, hoặc API lỗi)
            // Lúc này mới fallback về manager cũ
            freshManager = _currentDept.manager;
          }

          // 2. Cập nhật danh sách hiển thị Members (Trừ ông Manager ra)
          _members = deptMembers.where((e) {
            // Nếu đã tìm thấy Manager xịn, loại người đó ra khỏi list Members
            if (freshManager != null && freshManager.id != null) {
              return e.id != freshManager.id;
            }
            return true;
          }).toList();

          // 3. Cập nhật _currentDept với Manager MỚI NHẤT
          _currentDept = DepartmentModel(
            id: _currentDept.id,
            name: _currentDept.name,
            code: _currentDept.code,
            color: _currentDept.color,
            manager: freshManager, // Dùng Manager vừa tìm được
            isHr: _currentDept.isHr,
            memberIds: _currentDept.memberIds,
            memberCount: deptMembers.length,
          );

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Error fetching members: $e");
    }
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

  Future<void> _onAddMembers() async {
    // [BẢO VỆ] Chặn nếu không phải Admin
    if (_currentUserRole != 'COMPANY_ADMIN') return;

    final List<EmployeeModel>? finalSelection = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          alreadySelectedMembers: _members, // Truyền danh sách hiện tại
          excludeManagerId: _currentDept.manager?.id
              ?.toString(), // Loại trừ quản lý
        ),
      ),
    );

    // Nếu không chọn gì hoặc bấm Back thì thôi
    if (finalSelection == null) return;

    setState(() => _isLoading = true);

    try {
      // --- LOGIC CẬP NHẬT THÀNH VIÊN (DIFFING) ---

      // 1. Tìm ra ai cần thêm vào
      final oldIds = _members.map((e) => e.id).toSet();
      final toAdd = finalSelection
          .where((e) => !oldIds.contains(e.id))
          .toList();

      // 2. Tìm ra ai cần xóa đi (có trong list cũ nhưng không có trong list mới chọn)
      final newIds = finalSelection.map((e) => e.id).toSet();
      final toRemove = _members.where((e) => !newIds.contains(e.id)).toList();

      // 3. Gọi API cập nhật
      // - Thêm người mới vào phòng này
      for (var emp in toAdd) {
        await _updateMemberDept(emp, _currentDept.id);
      }
      // - Đuổi người cũ ra (set departmentId = 0 hoặc null)
      for (var emp in toRemove) {
        await _updateMemberDept(emp, 0);
      }

      // 4. Load lại dữ liệu mới nhất từ Server
      await _fetchMembers();

      if (mounted) {
        CustomSnackBar.show(
          context,
          title: 'Update Success',
          message: 'Added ${toAdd.length}, Removed ${toRemove.length} members.',
          isError: false,
        );
      }
    } catch (e) {
      print("Error updating members: $e");
      // Load lại để đảm bảo dữ liệu đúng
      _fetchMembers();
    }
  }

  Future<void> _updateMemberDept(EmployeeModel emp, int? deptId) async {
    if (emp.id == null || _currentUserId == null) return;

    // [BẢO VỆ] Chỉ Admin mới được xóa thành viên
    if (_currentUserRole != 'COMPANY_ADMIN') {
      CustomSnackBar.show(
        context,
        title: 'Permission Denied',
        message: 'Only Admin can remove members.',
        isError: true,
      );
      return;
    }

    try {
      await _employeeRepo.updateEmployee(
        _currentUserId!,
        emp.id!,
        emp.fullName,
        emp.phone,
        emp.dateOfBirth,
        email: emp.email,
        role: emp.role,
        status: emp.status,
        avatarUrl: emp.avatarUrl,
        departmentId: deptId,
      );
      _fetchMembers();
    } catch (e) {
      print("Error update dept for ${emp.fullName}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(widget.department.color);
    final manager = _currentDept.manager;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
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
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            color: AppColors.primary,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      const Expanded(
                        child: Text(
                          'DEPARTMENT DETAILS',
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
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Info Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.buildings(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  size: 40,
                                  color: themeColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _currentDept.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),

                              Text(
                                'Code: ${_currentDept.code ?? "N/A"}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_currentDept.memberCount} Members',
                                  style: const TextStyle(
                                    color: Color(0xFF4B5563),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // 2. MANAGER SECTION
                        if (manager != null) ...[
                          const Text(
                            'MANAGER',
                            style: TextStyle(
                              color: Color(0xFF655F5F),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          EmployeeCard(
                            employee: manager,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EmployeeProfilePage(employee: manager),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 3. MEMBERS HEADER + ADD BUTTON
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'MEMBERS',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),

                            // Chỉ hiện nút Add Member nếu là COMPANY_ADMIN
                            if (_currentUserRole == 'COMPANY_ADMIN')
                              InkWell(
                                onTap: _onAddMembers,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        PhosphorIcons.plus(
                                          PhosphorIconsStyle.bold,
                                        ),
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Add Member',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 4. MEMBER LIST (Đã bọc AnimatedSwitcher)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: _buildMemberList(),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    Widget content;
    Key contentKey;

    if (_isLoading) {
      contentKey = const ValueKey('loading_list');
      content = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) => const SkeletonEmployeeCard(),
      );
    } else if (_members.isEmpty) {
      contentKey = const ValueKey('empty_list');
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(PhosphorIcons.usersThree(), size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text(
              "No other members.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    } else {
      contentKey = const ValueKey('data_list');
      content = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final emp = _members[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: EmployeeCard(
              employee: emp,
              onMenuTap: null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmployeeProfilePage(employee: emp),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 50),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: contentKey, child: content),
    );
  }
}
