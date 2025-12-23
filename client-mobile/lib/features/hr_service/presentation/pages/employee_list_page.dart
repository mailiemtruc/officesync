import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- IMPORTS ---
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../data/datasources/employee_remote_data_source.dart';

import '../../widgets/employee_card.widget.dart';
import '../../widgets/department_card.widget.dart';
// [MỚI] Import BottomSheet của Department
import '../../widgets/department_bottom_sheet.dart';

import 'add_employee_page.dart';
import 'create_department_page.dart';
// [MỚI] Import trang chi tiết phòng ban nếu cần điều hướng
import 'department_details_page.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  bool _isEmployeesTab = true;
  bool _isLoading = true;

  List<EmployeeModel> _employees = [];
  List<DepartmentModel> _departments = [];

  // [MỚI] Biến lưu ID user hiện tại để ẩn khỏi danh sách
  String? _currentUserId;

  // [MỚI] Controller cho tìm kiếm
  final TextEditingController _searchController = TextEditingController();

  late final EmployeeRepository _employeeRepository;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _employeeRepository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );
    _fetchData();

    // [MỚI] Lắng nghe sự kiện nhập liệu để reload danh sách hiển thị
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC GỌI API ---
  Future<void> _fetchData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // Luôn lấy ID hiện tại trước để dùng cho việc filter
      _currentUserId = await _getCurrentUserId();

      if (_isEmployeesTab) {
        if (_currentUserId != null) {
          final data = await _employeeRepository.getEmployees(_currentUserId!);
          if (mounted) setState(() => _employees = data);
        }
      } else {
        final data = await _employeeRepository.getDepartments();
        if (mounted) setState(() => _departments = data);
      }
    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _navigateToAddPage() async {
    Route<bool> route;

    if (_isEmployeesTab) {
      route = MaterialPageRoute<bool>(
        builder: (context) => const AddEmployeePage(),
      );
    } else {
      route = MaterialPageRoute<bool>(
        builder: (context) => const CreateDepartmentPage(),
      );
    }

    final bool? result = await Navigator.push(context, route);

    if (!mounted) return;

    if (result == true) {
      _fetchData();
    }
  }

  void _onBottomNavTap(int index) {
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    } else if (index == 2) {
      Navigator.pushNamed(context, '/user_profile');
    }
  }

  // [MỚI] Hàm hiển thị BottomSheet cho Department
  void _showDepartmentOptions(DepartmentModel dept) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DepartmentBottomSheet(
        department: dept,
        onDeleteSuccess: () {
          // Callback: Reload dữ liệu sau khi xóa/sửa thành công
          _fetchData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      bottomNavigationBar: _buildBottomNavBar(),

      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPage,
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
                _buildHeader(),
                const SizedBox(height: 24),
                _buildTabs(),
                const SizedBox(height: 24),
                _buildSearchAndFilter(),
                const SizedBox(height: 20),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _fetchData,
                          child: _isEmployeesTab
                              ? _buildEmployeeList()
                              : _buildDepartmentList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    // [LOGIC MỚI] Filter danh sách theo Search Text và ẩn User hiện tại
    final String query = _searchController.text.toLowerCase();

    final filteredList = _employees.where((emp) {
      // 1. Ẩn user đang đăng nhập
      if (emp.id == _currentUserId) return false;

      // 2. Tìm kiếm theo Tên hoặc Mã nhân viên
      final nameMatches = emp.fullName.toLowerCase().contains(query);
      final codeMatches = (emp.employeeCode ?? '').toLowerCase().contains(
        query,
      );

      return nameMatches || codeMatches;
    }).toList();

    if (filteredList.isEmpty) {
      return _buildEmptyState("No employees found.");
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final emp = filteredList[index];
        return Padding(
          padding: index == filteredList.length - 1
              ? const EdgeInsets.only(bottom: 80)
              : EdgeInsets.zero,
          child: EmployeeCard(
            employee: emp,
            onMenuTap: () => _showOptions(context, "Employee: ${emp.fullName}"),
            onTap: () {},
          ),
        );
      },
    );
  }

  Widget _buildDepartmentList() {
    // [LOGIC MỚI] Filter danh sách phòng ban theo Search Text
    final String query = _searchController.text.toLowerCase();

    final filteredList = _departments.where((dept) {
      // Tìm kiếm theo Tên hoặc Mã phòng ban (property code)
      final nameMatches = dept.name.toLowerCase().contains(query);
      final codeMatches = (dept.code ?? '').toLowerCase().contains(query);
      return nameMatches || codeMatches;
    }).toList();

    if (filteredList.isEmpty) {
      return _buildEmptyState("No departments found.");
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final dept = filteredList[index];
        return Padding(
          padding: index == filteredList.length - 1
              ? const EdgeInsets.only(bottom: 80)
              : EdgeInsets.zero,
          child: DepartmentCard(
            department: dept,
            // [SỬA] Gọi hàm hiển thị BottomSheet thay vì hàm hiển thị text
            onMenuTap: () => _showDepartmentOptions(dept),
            // [MỚI] Thêm điều hướng sang trang chi tiết khi nhấn vào card
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DepartmentDetailsPage(department: dept),
                ),
              ).then((_) => _fetchData()); // Refresh khi quay về
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.ghost(), size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Hàm cũ dùng cho Employee (giữ nguyên hoặc nâng cấp sau)
  void _showOptions(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 150,
        color: Colors.white,
        child: Center(child: Text(title)),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: 1,
        onTap: _onBottomNavTap,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.house),
            activeIcon: Icon(PhosphorIconsFill.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsFill.squaresFour),
            activeIcon: Icon(PhosphorIconsFill.squaresFour),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.user),
            activeIcon: Icon(PhosphorIconsFill.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
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
    );
  }

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
          _buildTabItem("Employees", true),
          _buildTabItem("Departments", false),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, bool isEmployeeTab) {
    final bool isSelected = _isEmployeesTab == isEmployeeTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isEmployeesTab != isEmployeeTab) {
            setState(() {
              _isEmployeesTab = isEmployeeTab;
              // [MỚI] Xóa nội dung tìm kiếm khi chuyển tab
              _searchController.clear();
              _employees = [];
              _departments = [];
            });
            _fetchData();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
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
            title,
            style: TextStyle(
              color: isSelected ? AppColors.primary : const Color(0xFFB2AEAE),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchBar(
              hint: _isEmployeesTab
                  ? 'Search employee...'
                  : 'Search department...',
            ),
          ),
          const SizedBox(width: 12),
          Container(
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
        controller: _searchController, // [MỚI] Gắn controller vào
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
}
