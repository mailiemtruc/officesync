import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/department_model.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import 'add_members_page.dart';
import 'employee_profile_page.dart';

class DepartmentDetailsPage extends StatefulWidget {
  final DepartmentModel department;

  const DepartmentDetailsPage({super.key, required this.department});

  @override
  State<DepartmentDetailsPage> createState() => _DepartmentDetailsPageState();
}

class _DepartmentDetailsPageState extends State<DepartmentDetailsPage> {
  List<EmployeeModel> _members = [];
  bool _isLoading = true;
  late final EmployeeRepositoryImpl _employeeRepo;

  // [LOGIC MỚI] Khởi tạo storage
  final _storage = const FlutterSecureStorage();
  // [SỬA 1] Biến state để lưu thông tin phòng ban hiện tại
  late DepartmentModel _currentDept;

  @override
  void initState() {
    super.initState();
    _employeeRepo = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    // [SỬA 2] Copy dữ liệu từ widget sang biến local
    _currentDept = widget.department;

    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    // Nếu department chưa có ID (vừa tạo xong chưa sync), không load được
    if (widget.department.id == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // [CHUẨN DOANH NGHIỆP] Gọi API lấy đúng thành viên của phòng này thôi
      final deptMembers = await _employeeRepo.getEmployeesByDepartment(
        widget.department.id!,
      );

      if (mounted) {
        setState(() {
          // Chỉ cần lọc bỏ người Manager ra khỏi list hiển thị (nếu API trả về cả Manager)
          _members = deptMembers
              .where((e) => e.id != _currentDept.manager?.id)
              .toList();
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
    final List<EmployeeModel>? finalSelection = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          alreadySelectedMembers: _members,
          excludeManagerId: _currentDept.manager?.id?.toString(),
        ),
      ),
    );

    if (finalSelection == null) return;

    setState(() => _isLoading = true);

    // Logic Diffing (Giữ nguyên)
    final oldIds = _members.map((e) => e.id).toSet();
    final newIds = finalSelection.map((e) => e.id).toSet();
    final toAdd = finalSelection.where((e) => !oldIds.contains(e.id)).toList();
    final toRemove = _members.where((e) => !newIds.contains(e.id)).toList();

    // Gọi API (Giữ nguyên)
    for (var emp in toAdd) {
      await _updateMemberDept(emp, _currentDept.id);
    }
    for (var emp in toRemove) {
      await _updateMemberDept(emp, 0);
    }

    if (mounted) {
      setState(() {
        // 1. Cập nhật danh sách hiển thị (Gán cứng tên phòng ban để UI cập nhật ngay)
        _members = finalSelection.map((e) {
          return EmployeeModel(
            id: e.id,
            employeeCode: e.employeeCode,
            fullName: e.fullName,
            email: e.email,
            phone: e.phone,
            dateOfBirth: e.dateOfBirth,
            role: e.role,
            status: e.status,
            avatarUrl: e.avatarUrl,
            departmentName: _currentDept.name,
          );
        }).toList();

        _isLoading = false;

        // [SỬA LỖI ĐẾM SỐ LƯỢNG]
        // Nếu có Manager -> Tổng = Danh sách chọn + 1
        // Nếu không Manager -> Tổng = Danh sách chọn
        int totalCount = finalSelection.length;
        if (_currentDept.manager != null) {
          totalCount += 1;
        }

        _currentDept = DepartmentModel(
          id: _currentDept.id,
          name: _currentDept.name,
          code: _currentDept.code,
          color: _currentDept.color,
          manager: _currentDept.manager,
          memberCount: totalCount, // [QUAN TRỌNG] Dùng biến đã tính toán
          memberIds: _currentDept.memberIds,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated: Added ${toAdd.length}, Removed ${toRemove.length}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Helper function gọi API update (giúp code gọn hơn)
  Future<void> _updateMemberDept(EmployeeModel emp, int? deptId) async {
    if (emp.id == null) return;
    try {
      await _employeeRepo.updateEmployee(
        emp.id!,
        emp.fullName,
        emp.phone,
        emp.dateOfBirth,
        email: emp.email,
        role: emp.role,
        status: emp.status,
        avatarUrl: emp.avatarUrl,
        departmentId: deptId, // Truyền null nếu xóa
      );
    } catch (e) {
      print("Error update dept for ${emp.fullName}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(widget.department.color);
    final manager = widget.department.manager;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
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
                            'DEPARTMENT DETAILS',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
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
                                widget.department.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),

                              // [ĐÃ SỬA] Làm đậm phần Code
                              Text(
                                'Code: ${widget.department.code ?? "N/A"}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight
                                      .w600, // Đã thêm: Làm đậm chữ (Semi-bold)
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
                          // [SỬA ĐOẠN NÀY]
                          EmployeeCard(
                            employee: manager,
                            // Thêm điều hướng sang trang Profile của Manager
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

                            // Nút Add Member
                            InkWell(
                              onTap: _onAddMembers, // Gọi hàm vừa viết ở trên
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

                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "No other members.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final emp = _members[index];
                              return Padding(
                                // Nên bọc Padding để các card cách nhau ra chút
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: EmployeeCard(
                                  employee: emp,

                                  // [SỬA 2] Không truyền 'onMenuTap' -> Sẽ ẩn dấu 3 chấm (nếu EmployeeCard được code chuẩn)
                                  // onMenuTap: () {},

                                  // [SỬA 3] Thêm điều hướng sang trang chi tiết
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EmployeeProfilePage(employee: emp),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
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
}
