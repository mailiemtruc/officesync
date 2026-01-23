import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'core/config/app_colors.dart';

// Import các trang Home
import 'features/core_service/presentation/pages/staff_home_view.dart';
import 'features/core_service/presentation/pages/manager_home_view.dart';
import 'features/core_service/presentation/pages/director_home_view.dart';
import 'features/core_service/presentation/pages/admin_home_view.dart';
import 'dart:async';
// Import User Profile
import 'features/hr_service/presentation/pages/user_profile_page.dart';

// Import Services
import 'features/notification_service/notification_service.dart';
import 'features/hr_service/data/datasources/employee_remote_data_source.dart';
import 'features/ai_service/presentation/pages/ai_chat_screen.dart';
import '../../../../core/services/websocket_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  final int initialIndex; // <--- THÊM DÒNG NÀY
  const DashboardScreen({
    super.key,
    required this.userInfo,
    this.initialIndex = 0,
  });

  // Hàm static giúp các trang con có thể gọi để chuyển tab
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_DashboardScreenState>();
    if (state != null) {
      state.switchToTab(index);
    }
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;
  // Dùng IndexedStack để giữ trạng thái trang
  late List<Widget> _pages = [];
  bool _canAccessHrAttendance = false;
  bool _isLoading = true;

  // [QUAN TRỌNG] Biến lưu hàm hủy đăng ký Socket
  dynamic _unsubscribeFn;

  late Map<String, dynamic> _currentUserInfo;
  final EmployeeRemoteDataSource _employeeDataSource =
      EmployeeRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget
        .initialIndex; // <--- [QUAN TRỌNG] Gán index từ tham số truyền vào
    _initDashboardData();
  }

  // [SỬA LỖI] Phải hủy đăng ký khi thoát Dashboard (Logout)
  @override
  void dispose() {
    if (_unsubscribeFn != null) {
      _unsubscribeFn(unsubscribeHeaders: const <String, String>{});
    }
    super.dispose();
  }

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _initDashboardData() async {
    Map<String, dynamic> info = widget.userInfo;

    if (info.isEmpty || info['role'] == null || info['id'] == null) {
      try {
        String? storedJson = await _storage.read(key: 'user_info');
        if (storedJson != null) {
          info = jsonDecode(storedJson);
        }
      } catch (e) {
        print("Error reading storage: $e");
      }
    }

    _currentUserInfo = info;
    final String role = _currentUserInfo['role'] ?? 'STAFF';

    try {
      int userId = int.tryParse(_currentUserInfo['id'].toString()) ?? 0;
      if (userId > 0) {
        NotificationService().initNotifications(userId);
      }
    } catch (_) {}

    // Dựng khung trang ngay lập tức
    if (mounted) {
      setState(() {
        _updatePages(role);
        _isLoading = false;
      });
    }

    await _checkPermission();
    _setupRealtimePermissionListener();
  }

  Future<void> _checkPermission() async {
    final String role = _currentUserInfo['role'] ?? 'STAFF';
    int userId = int.tryParse(_currentUserInfo['id'].toString()) ?? 0;

    if (role == 'COMPANY_ADMIN') {
      if (mounted) {
        setState(() {
          _canAccessHrAttendance = true;
          _updatePages(role);
        });
      }
      return;
    }

    if ((role == 'MANAGER' || role == 'STAFF') && userId > 0) {
      try {
        final canAccess = await _employeeDataSource.checkHrPermission(userId);
        if (mounted) {
          setState(() {
            _canAccessHrAttendance = canAccess;
            _updatePages(role);
          });
        }
      } catch (e) {
        print("Error checking permission: $e");
      }
    }
  }

  // 1. Thêm từ khóa 'async' vào khai báo hàm
  Future<void> _setupRealtimePermissionListener() async {
    final userId = _currentUserInfo['id'];
    if (userId == null) return;
    final String hrSocketUrl = 'ws://10.0.2.2:8000/ws-hr';

    _unsubscribeFn = await WebSocketService().subscribe(
      '/topic/user/$userId/profile',
      (message) {
        if (message.toString().contains("REFRESH_PROFILE")) {
          print("--> [Dashboard] Received REFRESH_PROFILE signal");

          // [FIX UX] Hủy timer cũ, chỉ chạy timer mới sau 1 giây
          // Giúp gom nhiều thông báo cập nhật thành 1 lần gọi API duy nhất
          _refreshTimer?.cancel();
          _refreshTimer = Timer(const Duration(milliseconds: 1000), () {
            if (mounted) _refreshUserProfileFromApi();
          });
        }
      },
      forceUrl: hrSocketUrl,
    );
  }

  Future<void> _refreshUserProfileFromApi() async {
    try {
      final userId = _currentUserInfo['id'].toString();
      final employees = await _employeeDataSource.getEmployees(userId);

      final myProfile = employees.firstWhere(
        (e) => e.id == userId,
        orElse: () => throw Exception("User not found"),
      );

      // [FIX] Map đầy đủ trường dữ liệu để truyền xuống con
      final newInfo = {
        'id': myProfile.id,
        'email': myProfile.email,
        'fullName': myProfile.fullName,
        'role': myProfile.role,
        'phone': myProfile.phone,
        'mobileNumber': myProfile.phone, // Giữ key cũ để tương thích
        'dateOfBirth': myProfile.dateOfBirth,
        'avatarUrl': myProfile.avatarUrl,
        'token': _currentUserInfo['token'],
        // [QUAN TRỌNG] Thêm 2 trường này để trang con hiển thị luôn
        'employeeCode': myProfile.employeeCode,
        'departmentName': myProfile.departmentName,
        'companyName': _currentUserInfo['companyName'] ?? "OfficeSync",
      };

      await _storage.write(key: 'user_info', value: jsonEncode(newInfo));

      if (mounted) {
        setState(() {
          _currentUserInfo = newInfo;
          _updatePages(myProfile.role);
        });
        _checkPermission();
      }
    } catch (e) {
      print("Error refreshing profile realtime: $e");
    }
  }

  void _updatePages(String role) {
    _pages = [
      _buildHomeByRole(role),
      _buildMenuPage(role),
      // UserProfilePage sẽ nhận _currentUserInfo mới nhất khi hàm này được gọi
      UserProfilePage(
        key: const PageStorageKey('UserProfilePage'),
        userInfo: _currentUserInfo,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _currentIndex, children: _pages),

      floatingActionButton: SmartAiFab(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
          );
        },
      ),

      bottomNavigationBar: Container(
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
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.house),
              activeIcon: Icon(PhosphorIconsFill.house),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.squaresFour),
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
      ),
    );
  }

  // --- CÁC HÀM CON GIỮ NGUYÊN ---
  Widget _buildHomeByRole(String role) {
    int myId = int.tryParse(_currentUserInfo['id'].toString()) ?? 0;
    switch (role) {
      case 'SUPER_ADMIN':
        return AdminHomeView(currentUserId: myId);
      case 'COMPANY_ADMIN':
        return DirectorHomeView(currentUserId: myId);
      case 'MANAGER':
        return ManagerHomeView(currentUserId: myId);
      case 'STAFF':
      default:
        return StaffHomeView(currentUserId: myId);
    }
  }

  Widget _buildMenuPage(String role) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontFamily: 'Inter',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getDisplayRole(role),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSub,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (role == 'SUPER_ADMIN') {
                  return _buildSuperAdminMenu(context, constraints);
                } else {
                  return _buildCompanyMenu(context, constraints, role);
                }
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperAdminMenu(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final double itemWidth = (constraints.maxWidth - 16) / 2;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildMenuItem(
          context,
          title: 'Manage Companies',
          icon: PhosphorIconsFill.buildings,
          color: const Color(0xFF2563EB),
          route: '/admin_companies',
          width: itemWidth,
        ),
        _buildMenuItem(
          context,
          title: 'New Admin',
          icon: PhosphorIconsFill.userPlus,
          color: const Color(0xFF9333EA),
          route: '/create_admin',
          width: itemWidth,
        ),
        _buildMenuItem(
          context,
          title: 'System Analytics',
          icon: PhosphorIconsFill.chartLineUp,
          color: const Color(0xFFE11D48),
          route: '/analytics',
          width: itemWidth,
        ),
      ],
    );
  }

  Widget _buildCompanyMenu(
    BuildContext context,
    BoxConstraints constraints,
    String role,
  ) {
    final double itemWidth = (constraints.maxWidth - 16) / 2;
    bool isHrPersonnel =
        (role == 'COMPANY_ADMIN' ||
        role == 'HR_MANAGER' ||
        _canAccessHrAttendance);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildMenuItem(
          context,
          title: 'My Requests',
          icon: PhosphorIconsFill.fileText,
          color: const Color(0xFF3B82F6),
          route: '/my_requests',
          width: itemWidth,
        ),
        if (role == 'COMPANY_ADMIN' ||
            role == 'MANAGER' ||
            _canAccessHrAttendance)
          _buildMenuItem(
            context,
            title: 'Request Management',
            icon: PhosphorIconsFill.clipboardText,
            color: const Color(0xFFF97316),
            route: '/manager_requests',
            width: itemWidth,
          ),
        if (role == 'COMPANY_ADMIN' || role == 'MANAGER')
          _buildMenuItem(
            context,
            title: 'HR Management',
            icon: PhosphorIconsFill.usersThree,
            color: const Color(0xFF8B5CF6),
            route: '/employees',
            width: itemWidth,
          ),
        _buildMenuItem(
          context,
          title: 'Personal Notes',
          icon: PhosphorIconsRegular.notePencil,
          color: const Color(0xFFFFB74D),
          route: '/notes',
          width: itemWidth,
        ),
        _buildMenuItem(
          context,
          title: 'Task Management',
          icon: PhosphorIconsFill.checkSquare,
          color: const Color(0xFF10B981),
          route: '/tasks',
          arguments: role,
          width: itemWidth,
        ),
        _buildMenuItem(
          context,
          title: 'Attendance',
          icon: PhosphorIconsFill.mapPin,
          color: const Color(0xFFEC4899),
          route: '/attendance',
          width: itemWidth,
        ),
        if (isHrPersonnel)
          _buildMenuItem(
            context,
            title: 'HR Attendance',
            icon: PhosphorIconsFill.chartBar,
            color: Colors.indigo,
            route: '/manager_attendance',
            width: itemWidth,
            arguments: (role == 'COMPANY_ADMIN')
                ? 'COMPANY_ADMIN'
                : 'HR_MANAGER',
          ),
        if (role == 'COMPANY_ADMIN')
          _buildMenuItem(
            context,
            title: 'Company Profile',
            icon: PhosphorIconsFill.buildings,
            color: const Color(0xFF06B6D4),
            route: '/company_profile',
            width: itemWidth,
          ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required double width,
    Object? arguments,
    VoidCallback? onTapOverride,
  }) {
    return Container(
      width: width,
      height: 140,
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap:
              onTapOverride ??
              () => Navigator.pushNamed(context, route, arguments: arguments),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayRole(String rawRole) {
    switch (rawRole) {
      case 'SUPER_ADMIN':
        return 'ADMIN';
      case 'COMPANY_ADMIN':
        return 'DIRECTOR';
      case 'MANAGER':
        return 'MANAGER';
      case 'STAFF':
        return 'STAFF';
      default:
        return rawRole;
    }
  }
}

class SmartAiFab extends StatefulWidget {
  final VoidCallback onPressed;
  const SmartAiFab({super.key, required this.onPressed});

  @override
  State<SmartAiFab> createState() => _SmartAiFabState();
}

class _SmartAiFabState extends State<SmartAiFab> with TickerProviderStateMixin {
  late AnimationController _bubbleController;
  late Animation<double> _bubbleAnimation;
  late AnimationController _pulseController;
  final List<String> _aiMessages = [
    "Ready to assist",
    "How can I help?",
    "Check attendance",
    "View tasks",
    "Any questions?",
  ];
  String _currentMessage = "OfficeSync AI";

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bubbleAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _scheduleMessageLoop();
  }

  void _scheduleMessageLoop() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _currentMessage = _aiMessages[DateTime.now().second % _aiMessages.length];
    });
    _bubbleController.forward();
    await Future.delayed(const Duration(seconds: 6));
    if (!mounted) return;
    _bubbleController.reverse();

    while (mounted) {
      await Future.delayed(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _currentMessage =
            _aiMessages[DateTime.now().second % _aiMessages.length];
      });
      _bubbleController.forward();
      await Future.delayed(const Duration(seconds: 6));
      if (!mounted) return;
      _bubbleController.reverse();
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      // [SỬA 1] Đổi Column thành Row để xếp ngang
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // Căn giữa theo chiều dọc
      children: [
        // --- PHẦN BONG BÓNG TIN NHẮN ---
        FadeTransition(
          opacity: _bubbleAnimation,
          child: SlideTransition(
            // [SỬA 2] Đổi hướng trượt: Từ phải sang trái (như chui ra từ nút)
            position: Tween<Offset>(
              begin: const Offset(0.2, 0),
              end: Offset.zero,
            ).animate(_bubbleAnimation),
            child: Container(
              // [SỬA 3] Chỉnh margin: Bỏ bottom, thêm right để cách nút ra
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(0xFF2260FF).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _currentMessage,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),

        // --- PHẦN NÚT TRÒN (FAB) GIỮ NGUYÊN ---
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.3, end: 0.0).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.5).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onPressed,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
