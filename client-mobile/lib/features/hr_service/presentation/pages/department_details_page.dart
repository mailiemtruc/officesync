import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/department_model.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';
// 1. Import Bottom Sheet để nút 3 chấm hoạt động
import '../../widgets/employee_bottom_sheet.dart';
// 2. Import trang AddMembers để nút Add new hoạt động
import 'add_members_page.dart';

class DepartmentDetailsPage extends StatefulWidget {
  final Department department;

  const DepartmentDetailsPage({super.key, required this.department});

  @override
  State<DepartmentDetailsPage> createState() => _DepartmentDetailsPageState();
}

class _DepartmentDetailsPageState extends State<DepartmentDetailsPage> {
  // Mock Data (Thực tế lấy từ API)
  final List<Employee> _allEmployees = [
    Employee(
      id: "001",
      name: "Nguyen Van A",
      role: "Manager",
      department: "Business",
      imageUrl: "https://i.pravatar.cc/150?img=11",
    ),
    Employee(
      id: "002",
      name: "Tran Thi B",
      role: "Staff",
      department: "HR Department",
      imageUrl: "https://i.pravatar.cc/150?img=5",
    ),
    Employee(
      id: "003",
      name: "Nguyen Van C",
      role: "Staff",
      department: "Business",
      imageUrl: "https://i.pravatar.cc/150?img=3",
    ),
    Employee(
      id: "004",
      name: "Nguyen Van E",
      role: "Manager",
      department: "HR Department",
      imageUrl: "https://i.pravatar.cc/150?img=8",
    ),
    Employee(
      id: "005",
      name: "Le Van F",
      role: "Staff",
      department: "HR Department",
      imageUrl: "https://i.pravatar.cc/150?img=12",
    ),
  ];

  late Employee? _manager;
  late List<Employee> _members;

  @override
  void initState() {
    super.initState();
    _filterData();
  }

  void _filterData() {
    try {
      _manager = _allEmployees.firstWhere(
        (e) => e.name == widget.department.managerName,
        orElse: () => _allEmployees.firstWhere(
          (e) =>
              e.department == widget.department.name &&
              (e.role == 'Manager' || e.role == 'Management'),
          orElse: () => Employee(
            id: "000",
            name: "N/A",
            role: "Manager",
            department: "",
            imageUrl: "",
          ),
        ),
      );
    } catch (e) {
      _manager = null;
    }

    _members = _allEmployees.where((e) {
      // Lấy nhân viên cùng phòng ban (trừ ông quản lý ra)
      return e.department == widget.department.name && e.id != _manager?.id;
    }).toList();
  }

  // --- HÀM MỚI: Hiển thị Bottom Sheet khi nhấn 3 chấm ---
  void _showEmployeeOptions(Employee emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmployeeBottomSheet(
        employee: emp,
        onToggleLock: () {
          setState(() {
            emp.isLocked = !emp.isLocked;
          });
        },
        onDelete: () {
          setState(() {
            // Xóa khỏi danh sách hiển thị
            _members.removeWhere((e) => e.id == emp.id);
            // (Thực tế cần gọi API xóa khỏi DB)
          });
        },
      ),
    );
  }

  // --- HÀM MỚI: Mở trang thêm thành viên ---
  Future<void> _navigateToAddMembers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersPage(
          // Truyền vào danh sách hiện tại để đánh dấu đã chọn
          alreadySelectedMembers: _members,
        ),
      ),
    );

    // Cập nhật lại danh sách nếu có thay đổi
    if (result != null && result is List<Employee>) {
      setState(() {
        _members = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        // 1. Department Info Card
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
                                  color: widget.department.themeColor
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.buildings(
                                    PhosphorIconsStyle.fill,
                                  ),
                                  size: 40,
                                  color: widget.department.themeColor,
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
                              Text(
                                'Code: ${widget.department.code}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
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
                                  '${_members.length + (_manager != null ? 1 : 0)} Members',
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

                        // 2. MANAGER
                        if (_manager != null && _manager!.id != "000") ...[
                          _buildSectionTitle('MANAGER'),
                          const SizedBox(height: 12),
                          EmployeeCard(
                            name: _manager!.name,
                            employeeId: _manager!.id,
                            role: _manager!.role,
                            department: _manager!.department,
                            imageUrl: _manager!.imageUrl,
                            isLocked: _manager!.isLocked,
                            // Truyền hàm mở menu vào đây
                            onMenuTap: () => _showEmployeeOptions(_manager!),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 3. MEMBERS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle('MEMBERS (${_members.length})'),
                            // Nút Add New (Đã gắn hàm điều hướng)
                            InkWell(
                              onTap: _navigateToAddMembers,
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Add new',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "No members yet.",
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
                              return EmployeeCard(
                                name: emp.name,
                                employeeId: emp.id,
                                role: emp.role,
                                department: emp.department,
                                imageUrl: emp.imageUrl,
                                isLocked: emp.isLocked,
                                // Truyền hàm mở menu vào đây để nút 3 chấm hoạt động
                                onMenuTap: () => _showEmployeeOptions(emp),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF655F5F),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        letterSpacing: 0.5,
      ),
    );
  }
}
