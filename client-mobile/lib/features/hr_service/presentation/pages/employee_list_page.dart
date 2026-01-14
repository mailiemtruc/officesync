import 'dart:async'; // Dùng cho Debounce
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:officesync/features/hr_service/domain/repositories/employee_repository.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/department_model.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
// Import Department Repository & DataSource
import '../../domain/repositories/department_repository.dart';
import '../../data/datasources/department_remote_data_source.dart';
import '../../domain/repositories/department_repository_impl.dart';
import '../../domain/repositories/department_repository.dart';
import '../../widgets/employee_card.widget.dart';
import '../../widgets/department_card.widget.dart';
import '../../widgets/department_bottom_sheet.dart'; // Đảm bảo đã import cái này
import '../../widgets/employee_bottom_sheet.dart';
import 'add_employee_page.dart';
import 'create_department_page.dart';
import 'department_details_page.dart';
import '../../../../core/utils/custom_snackbar.dart';
import 'employee_profile_page.dart';

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
  // Biến lưu Role và Tên phòng ban của user hiện tại
  String? _currentUserRole;
  String? _currentUserDeptName;

  // Controller cho tìm kiếm
  final TextEditingController _searchController = TextEditingController();

  // Timer để xử lý Debounce
  Timer? _debounce;

  late final EmployeeRepository _employeeRepository;
  late final DepartmentRepository _departmentRepository;

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();

    // Khởi tạo Repositories
    _employeeRepository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );
    _departmentRepository = DepartmentRepositoryImpl(
      remoteDataSource: DepartmentRemoteDataSource(),
    );

    _fetchData();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(keyword: _searchController.text);
    });
  }

  // --- LOGIC GỌI API & PHÂN QUYỀN ---
  Future<void> _fetchData({String keyword = ''}) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      _currentUserId = await _getCurrentUserId();

      if (_currentUserId != null) {
        List<EmployeeModel> apiResult;

        // Backend đã lọc dữ liệu theo quyền (Data Scoping)
        if (keyword.isEmpty) {
          apiResult = await _employeeRepository.getEmployees(_currentUserId!);
        } else {
          apiResult = await _employeeRepository.searchEmployees(
            _currentUserId!,
            keyword,
          );
        }

        // Cập nhật Role User hiện tại
        if (_currentUserRole == null || keyword.isEmpty) {
          try {
            final me = apiResult.firstWhere(
              (e) => e.id == _currentUserId,
              orElse: () => apiResult.isNotEmpty
                  ? apiResult[0]
                  : EmployeeModel(
                      id: "0",
                      fullName: "",
                      email: "",
                      phone: "",
                      dateOfBirth: "",
                      role: "STAFF",
                    ),
            );

            if (me.id == _currentUserId) {
              _currentUserRole = me.role.toUpperCase();
              _currentUserDeptName = me.departmentName;
            }
          } catch (e) {
            print("Info: Current user not found in the fetched list.");
          }
        }

        // GÁN DỮ LIỆU
        if (_isEmployeesTab) {
          _employees = apiResult;
          // Tìm đoạn code trong hàm _fetchData và sửa lại:
        } else {
          // Tab Departments
          List<DepartmentModel> deptData;

          if (keyword.isEmpty) {
            // [ĐÃ SỬA] Truyền _currentUserId vào hàm getDepartments
            // Lưu ý: _currentUserId đã được check null ở đầu hàm _fetchData nên an toàn
            deptData = await _employeeRepository.getDepartments(
              _currentUserId!,
            );
          } else {
            deptData = await _departmentRepository.searchDepartments(
              _currentUserId ?? '',
              keyword,
            );
          }
          if (mounted) setState(() => _departments = deptData);
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      print("Error fetching data: $e");
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
    if (!_isEmployeesTab && _currentUserRole == 'MANAGER') {
      CustomSnackBar.show(
        context,
        title: 'Permission Denied',
        message: 'Managers cannot create departments.',
        isError: true,
      );
      return;
    }

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

  // --- MENU NHÂN VIÊN ---
  void _showOptions(BuildContext context, EmployeeModel employee) async {
    final result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EmployeeBottomSheet(
        employee: employee,
        onToggleLock: () => _handleToggleLock(employee),
        onDelete: () => _handleDeleteEmployee(employee.id!),
      ),
    );

    if (result == true) {
      _fetchData(keyword: _searchController.text);
    }
  }

  // --- [ĐÃ SỬA] MENU PHÒNG BAN ---
  void _showDepartmentOptions(DepartmentModel dept) async {
    // Gọi BottomSheet từ file widget bên ngoài
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DepartmentBottomSheet(
        department: dept,
        // Callback khi xóa/sửa thành công -> Load lại list
        onDeleteSuccess: () {
          _fetchData(keyword: _searchController.text);
        },
      ),
    );

    // Sau khi đóng bottom sheet, load lại data cho chắc chắn
    _fetchData(keyword: _searchController.text);
  }

  Future<void> _handleDeleteEmployee(String targetId) async {
    // Đổi tên tham số thành targetId cho rõ
    try {
      // [FIX LỖI] Kiểm tra null
      if (_currentUserId == null) {
        CustomSnackBar.show(
          context,
          title: 'Session Error',
          message: 'Session expired. Please login again.',
          isError: true,
        );
        return;
      }

      // [FIX LỖI] Truyền 2 tham số: (Người xóa, Người bị xóa)
      bool success = await _employeeRepository.deleteEmployee(
        _currentUserId!,
        targetId,
      );

      if (mounted) {
        if (success) {
          CustomSnackBar.show(
            context,
            title: 'Success',
            message: 'Employee deleted successfully',
            isError: false,
          );
          _fetchData();
        } else {
          CustomSnackBar.show(
            context,
            title: 'Failed',
            message: 'Failed to delete employee',
            isError: true,
          );
        }
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  Future<void> _handleToggleLock(EmployeeModel emp) async {
    if (_currentUserId == null) {
      CustomSnackBar.show(
        context,
        title: 'Session Error',
        message: 'Session expired. Please login again.',
        isError: true,
      );
      return;
    }

    String newStatus = emp.status == 'ACTIVE' ? 'LOCKED' : 'ACTIVE';
    try {
      bool success = await _employeeRepository.updateEmployee(
        _currentUserId!,
        emp.id!,
        emp.fullName,
        emp.phone,
        emp.dateOfBirth,
        status: newStatus,
        email: emp.email,
        role: emp.role,
        departmentId: null,
      );

      if (mounted) {
        if (success) {
          CustomSnackBar.show(
            context,
            title: 'Success',
            message: 'Account is now $newStatus',
            isError: false,
          );
          _fetchData(keyword: _searchController.text);
        } else {
          CustomSnackBar.show(
            context,
            title: 'Error',
            message: 'Failed to update status',
            isError: true,
          );
        }
      }
    } catch (e) {
      print("Status update error: $e");
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: 'Error',
          message: 'Error: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showFab = true;

    if (_currentUserRole == 'STAFF') {
      showFab = false;
    } else if (!_isEmployeesTab && _currentUserRole != 'COMPANY_ADMIN') {
      showFab = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      bottomNavigationBar: _buildBottomNavBar(),

      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: _navigateToAddPage,
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,

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
            onMenuTap: () => _showOptions(context, emp),
            onTap: () {
              // [ĐÃ SỬA] Chuyển hướng sang trang Profile (Xem chi tiết)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeProfilePage(employee: emp),
                ),
              ).then(
                (_) => _fetchData(),
              ); // Vẫn giữ fetch lại data đề phòng có sửa trong trang chi tiết
            },
          ),
        );
      },
    );
  }

  Widget _buildDepartmentList() {
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

            // [SỬA QUAN TRỌNG] Gọi hàm _showDepartmentOptions thay vì navigate
            onMenuTap: (_currentUserRole == 'COMPANY_ADMIN')
                ? () =>
                      _showDepartmentOptions(dept) // [ĐÃ SỬA]
                : null,

            // [SỬA ĐOẠN NÀY]
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DepartmentDetailsPage(department: dept),
                ),
              ).then((_) {
                // [QUAN TRỌNG] Load lại dữ liệu khi quay về để cập nhật Manager mới
                _fetchData(keyword: _searchController.text);
              });
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
      child: _buildSearchBar(
        hint: _isEmployeesTab
            ? 'Search name, employee ID...'
            : 'Search name, department ID...',
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
        // Cập nhật UI liên tục khi gõ để hiện/ẩn nút xóa
        onChanged: (value) {
          setState(() {});
        },
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
          // [ĐÃ SỬA] Nút xóa dùng PhosphorIcons + Giao diện hình tròn đẹp
          suffixIcon: _searchController.text.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10.0), // Padding để nút nhỏ gọn
                  child: GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {}); // Cập nhật UI để ẩn nút

                      // Hủy debounce cũ và load lại danh sách gốc
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _fetchData(keyword: '');
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFC4C4C4), // Màu nền xám bo tròn
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        // Nếu ".x" báo lỗi, hãy thử đổi thành ".x_" hoặc ".close"
                        PhosphorIcons.x(PhosphorIconsStyle.bold),
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
