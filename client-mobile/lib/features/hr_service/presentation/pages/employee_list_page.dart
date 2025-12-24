import 'dart:async'; // [MỚI] Import để dùng Timer cho Debounce
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
// Import Department Repository & DataSource
import '../../domain/repositories/department_repository.dart'; // [MỚI]
import '../../data/datasources/department_remote_data_source.dart'; // [MỚI]

import '../../widgets/employee_card.widget.dart';
import '../../widgets/department_card.widget.dart';
import '../../widgets/department_bottom_sheet.dart';

import 'add_employee_page.dart';
import 'create_department_page.dart';
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

  String? _currentUserId;

  // Controller cho tìm kiếm
  final TextEditingController _searchController = TextEditingController();

  // [MỚI] Timer để xử lý Debounce (tránh spam API khi gõ)
  Timer? _debounce;

  late final EmployeeRepository _employeeRepository;
  // [MỚI] Khai báo thêm DepartmentRepository để search phòng ban
  late final DepartmentRepository _departmentRepository;

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    // Khởi tạo Repositories
    _employeeRepository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );
    _departmentRepository = DepartmentRepository(
      remoteDataSource: DepartmentRemoteDataSource(),
    );

    _fetchData();

    // [MỚI] Lắng nghe sự kiện nhập liệu với Debounce
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    // [MỚI] Hủy Timer và Controller
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // [MỚI] Hàm xử lý khi người dùng nhập text (Debounce 500ms)
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Chỉ gọi API sau khi người dùng ngừng gõ 0.5s
      _fetchData(keyword: _searchController.text);
    });
  }

  // --- LOGIC GỌI API (Đã nâng cấp Server-side Search) ---
  Future<void> _fetchData({String keyword = ''}) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      _currentUserId = await _getCurrentUserId();

      if (_isEmployeesTab) {
        if (_currentUserId != null) {
          List<EmployeeModel> data;

          if (keyword.isEmpty) {
            // Nếu không tìm kiếm -> Lấy tất cả
            data = await _employeeRepository.getEmployees(_currentUserId!);
          } else {
            // Nếu có từ khóa -> Gọi API Search của Backend
            // Lưu ý: Đảm bảo EmployeeRepository đã có hàm searchEmployees kết nối với RemoteDataSource
            data = await _employeeRepository.searchEmployees(
              _currentUserId!,
              keyword,
            );
          }

          if (mounted) setState(() => _employees = data);
        }
      } else {
        // Tab Departments
        List<DepartmentModel> data;

        if (keyword.isEmpty) {
          // Lấy tất cả (Dùng hàm cũ từ EmployeeRepo hoặc DepartmentRepo tùy cấu trúc của bạn)
          data = await _employeeRepository.getDepartments();
        } else {
          // Tìm kiếm (Dùng DepartmentRepo mới sửa)
          data = await _departmentRepository.searchDepartments(
            _currentUserId ?? '',
            keyword,
          );
        }

        if (mounted) setState(() => _departments = data);
      }
    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) {
        // Có thể hiện thông báo lỗi nhẹ nhàng hoặc bỏ qua nếu đang search
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

  void _showDepartmentOptions(DepartmentModel dept) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DepartmentBottomSheet(
        department: dept,
        onDeleteSuccess: () {
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
                          onRefresh: () async =>
                              _fetchData(keyword: _searchController.text),
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
    // [LOGIC MỚI] Dữ liệu đã được lọc từ Server.
    // Client chỉ cần ẩn User hiện tại.
    final filteredList = _employees.where((emp) {
      return emp.id != _currentUserId;
    }).toList();

    if (filteredList.isEmpty) {
      String msg = _searchController.text.isNotEmpty
          ? "No employees found matching '${_searchController.text}'"
          : "No employees found.";
      return _buildEmptyState(msg);
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
    // [LOGIC MỚI] Dữ liệu đã được lọc từ Server. Hiển thị trực tiếp.
    if (_departments.isEmpty) {
      String msg = _searchController.text.isNotEmpty
          ? "No departments found matching '${_searchController.text}'"
          : "No departments found.";
      return _buildEmptyState(msg);
    }

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
            onMenuTap: () => _showDepartmentOptions(dept),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DepartmentDetailsPage(department: dept),
                ),
              ).then((_) => _fetchData());
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
              // Xóa nội dung tìm kiếm khi chuyển tab
              _searchController.clear();
              // Reset list để tránh hiển thị data cũ
              _employees = [];
              _departments = [];
            });
            // Gọi lại API mặc định (không keyword)
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
        controller: _searchController,
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
