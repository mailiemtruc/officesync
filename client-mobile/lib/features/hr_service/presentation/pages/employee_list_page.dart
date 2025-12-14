import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import Config & Widgets
import '../../../../core/config/app_colors.dart';
import '../../widgets/employee_card.widget.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_bottom_sheet.dart';
// Import trang AddEmployeePage (sửa đường dẫn nếu cần)
import 'add_employee_page.dart';
// Import mới cho Departments
import '../../data/models/department_model.dart';
import '../../widgets/department_card.widget.dart';
import '../../widgets/department_bottom_sheet.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  bool _isEmployeesTab = true; // Biến trạng thái để switch tab

  // Dữ liệu Nhân viên (Giữ nguyên)
  final List<Employee> _employees = [
    Employee(
      id: "001",
      name: "Nguyen Van A",
      role: "Manager",
      department: "Business",
      imageUrl: "https://i.pravatar.cc/150?img=11",
      isLocked: false,
    ),
    Employee(
      id: "002",
      name: "Tran Thi B",
      role: "Staff",
      department: "Human resources",
      imageUrl: "https://i.pravatar.cc/150?img=5",
      isLocked: false,
    ),
    Employee(
      id: "003",
      name: "Nguyen Van C",
      role: "Staff",
      department: "Technical",
      imageUrl: "https://i.pravatar.cc/150?img=3",
      isLocked: true,
    ),
    Employee(
      id: "004",
      name: "Nguyen Van E",
      role: "Manager",
      department: "Human resources",
      imageUrl: "https://i.pravatar.cc/150?img=8",
      isLocked: false,
    ),
  ];

  // Dữ liệu Phòng ban (Mới thêm)
  final List<Department> _departments = [
    Department(
      id: "D1",
      name: "Business Department",
      code: "DEP-001",
      managerName: "Nguyen Van A",
      // Ảnh quản lý (dùng link giống Employee A)
      managerImageUrl: "https://i.pravatar.cc/150?img=11",
      memberCount: 12,
      themeColor: const Color(0xFF2260FF), // Xanh
    ),
    Department(
      id: "D2",
      name: "HR Department",
      code: "DEP-002",
      managerName: "Nguyen Van E",
      // Ảnh quản lý (dùng link giống Employee E)
      managerImageUrl: "https://i.pravatar.cc/150?img=8",
      memberCount: 8,
      themeColor: const Color(0xFFD946EF), // Hồng tím (như thiết kế)
    ),
    Department(
      id: "D3",
      name: "Technical Department",
      code: "DEP-003",
      managerName: "Nguyen Van F",
      // Ảnh quản lý
      managerImageUrl: "https://i.pravatar.cc/150?img=60",
      memberCount: 9,
      themeColor: const Color(0xFFF97316), // Cam
    ),
  ];

  // Hàm mở BottomSheet Nhân viên
  void _showEmployeeOptions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: EmployeeBottomSheet(
                employee: _employees[index],
                onToggleLock: () => setState(
                  () =>
                      _employees[index].isLocked = !_employees[index].isLocked,
                ),
                onDelete: () => setState(() => _employees.removeAt(index)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Hàm mở BottomSheet Phòng ban (Mới)
  void _showDepartmentOptions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: DepartmentBottomSheet(
                department: _departments[index],
                onDelete: () => setState(() => _departments.removeAt(index)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isEmployeesTab) {
            // Nếu đang ở tab Nhân viên -> Chuyển sang trang Thêm Nhân viên
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddEmployeePage()),
            );
          } else {
            // Nếu đang ở tab Phòng ban -> Xử lý thêm phòng ban (TODO sau này)
            // Ví dụ: Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDepartmentPage()));
          }
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            color: AppColors.primary,
                            size: 24,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Text(
                        'COMPANY HR',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildTabs(), // Tab Switcher

                const SizedBox(height: 24),
                // Search Bar (Đổi hint text theo tab)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSearchBar(
                          hint: _isEmployeesTab
                              ? 'Search name, employee ID...'
                              : 'Search name, department code...',
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildFilterButton(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Nội dung danh sách (Thay đổi theo Tab)
                Expanded(
                  child: _isEmployeesTab
                      ? _buildEmployeeList()
                      : _buildDepartmentList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget hiển thị danh sách Nhân viên
  Widget _buildEmployeeList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: _employees.length,
      itemBuilder: (context, index) {
        final emp = _employees[index];
        return Padding(
          padding: index == _employees.length - 1
              ? const EdgeInsets.only(bottom: 80)
              : EdgeInsets.zero,
          child: EmployeeCard(
            name: emp.name,
            employeeId: emp.id,
            role: emp.role,
            department: emp.department,
            imageUrl: emp.imageUrl,
            isLocked: emp.isLocked,
            onMenuTap: () => _showEmployeeOptions(context, index),
          ),
        );
      },
    );
  }

  // Widget hiển thị danh sách Phòng ban (Mới)
  Widget _buildDepartmentList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: _departments.length,
      itemBuilder: (context, index) {
        final dept = _departments[index];
        return Padding(
          padding: index == _departments.length - 1
              ? const EdgeInsets.only(bottom: 80)
              : EdgeInsets.zero,
          child: DepartmentCard(
            department: dept,
            onMenuTap: () => _showDepartmentOptions(context, index),
          ),
        );
      },
    );
  }

  // --- Các Widget phụ trợ (Tabs, Search, Filter) giữ nguyên style ---
  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isEmployeesTab = true),
              child: Container(
                decoration: BoxDecoration(
                  color: _isEmployeesTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isEmployeesTab
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Employees',
                  style: TextStyle(
                    color: _isEmployeesTab
                        ? AppColors.primary
                        : const Color(0xFFB2AEAE),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isEmployeesTab = false),
              child: Container(
                decoration: BoxDecoration(
                  color: !_isEmployeesTab ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isEmployeesTab
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Departments',
                  style: TextStyle(
                    color: !_isEmployeesTab
                        ? AppColors.primary
                        : const Color(0xFFB2AEAE),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({required String hint}) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(),
            color: const Color(0xFF757575),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: IconButton(
        icon: Icon(
          PhosphorIcons.funnel(PhosphorIconsStyle.regular),
          color: const Color(0xFF555252),
          size: 20,
        ),
        onPressed: () {},
      ),
    );
  }
}
