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

// Import User Profile
import 'features/hr_service/presentation/pages/user_profile_page.dart';

// Import Services
import 'features/notification_service/notification_service.dart';
import 'features/hr_service/data/datasources/employee_remote_data_source.dart';
import 'features/ai_service/presentation/pages/ai_chat_screen.dart';
import '../../../../core/services/websocket_service.dart'; // [QUAN TRỌNG] Socket Service

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const DashboardScreen({super.key, required this.userInfo});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _storage = const FlutterSecureStorage();

  // Dùng IndexedStack để giữ trạng thái trang
  late List<Widget> _pages = [];
  bool _canAccessHrAttendance = false;
  bool _isLoading = true;

  // Biến lưu thông tin chính thức của Dashboard (Source of Truth)
  late Map<String, dynamic> _currentUserInfo;

  // DataSource để gọi API lấy thông tin mới
  final EmployeeRemoteDataSource _employeeDataSource =
      EmployeeRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _initDashboardData();
  }

  // 1. KHỞI TẠO DỮ LIỆU & KHÔI PHỤC NẾU CẦN
  Future<void> _initDashboardData() async {
    Map<String, dynamic> info = widget.userInfo;

    // Nếu widget.userInfo bị thiếu Role hoặc ID (do điều hướng lỗi), đọc từ Storage
    if (info.isEmpty || info['role'] == null || info['id'] == null) {
      try {
        String? storedJson = await _storage.read(key: 'user_info');
        if (storedJson != null) {
          info = jsonDecode(storedJson);
          print("--> Dashboard: Recovered user info from Storage.");
        }
      } catch (e) {
        print("--> Dashboard: Error reading storage: $e");
      }
    }

    _currentUserInfo = info;
    final String role = _currentUserInfo['role'] ?? 'STAFF';

    // Init Notification Service
    try {
      int userId = int.tryParse(_currentUserInfo['id'].toString()) ?? 0;
      if (userId > 0) {
        NotificationService().initNotifications(userId);
      }
    } catch (_) {}

    // Xây dựng giao diện ban đầu
    if (mounted) {
      setState(() {
        _updatePages(role);
        _isLoading = false;
      });
    }

    // Check quyền HR & Kích hoạt lắng nghe Real-time
    await _checkPermission();
    _setupRealtimePermissionListener();
  }

  // 2. KIỂM TRA QUYỀN TRUY CẬP HR (Dựa trên API)
  Future<void> _checkPermission() async {
    final String role = _currentUserInfo['role'] ?? 'STAFF';
    int userId = int.tryParse(_currentUserInfo['id'].toString()) ?? 0;

    // Trường hợp 1: Admin -> Luôn cho phép
    if (role == 'COMPANY_ADMIN') {
      if (mounted) {
        setState(() {
          _canAccessHrAttendance = true;
          _updatePages(role); // Update lại menu để hiện nút HR Attendance
        });
      }
      return;
    }

    // Trường hợp 2: Manager/Staff -> Check server xem có phải thuộc phòng HR không
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

  // 3. LẮNG NGHE SOCKET ĐỂ CẬP NHẬT QUYỀN TỨC THÌ
  void _setupRealtimePermissionListener() {
    final userId = _currentUserInfo['id'];
    if (userId == null) return;

    final wsService = WebSocketService();

    // Đảm bảo kết nối nếu chưa kết nối
    if (!wsService.isConnected) {
      wsService.connect();
      print("Socket Connected for Dashboard");
    }

    // Subscribe topic riêng tư: /topic/user/{id}/profile
    wsService.subscribe('/topic/user/$userId/profile', (message) async {
      if (message == "REFRESH_PROFILE") {
        print("--> TÍN HIỆU: Cập nhật Profile/Quyền hạn từ Server");

        // [QUAN TRỌNG] Thêm Delay 500ms để chờ Backend commit Transaction xong
        // Tránh trường hợp Mobile gọi API quá nhanh khi Server chưa lưu kịp dữ liệu mới
        await Future.delayed(const Duration(milliseconds: 500));

        // Tiến hành gọi API lấy dữ liệu mới
        _refreshUserProfileFromApi();
      }
    });
  }

  // 4. GỌI API LẤY THÔNG TIN MỚI NHẤT & CẬP NHẬT UI
  Future<void> _refreshUserProfileFromApi() async {
    try {
      final userId = _currentUserInfo['id'].toString();

      // Gọi API lấy danh sách nhân viên (hoặc chi tiết nhân viên) mới nhất
      final employees = await _employeeDataSource.getEmployees(userId);

      // Tìm thông tin của chính mình trong danh sách trả về
      final myProfile = employees.firstWhere(
        (e) => e.id == userId,
        orElse: () => throw Exception("User not found in response"),
      );

      // Tạo map thông tin mới (Lưu ý: Phải giữ lại Token cũ để không bị logout)
      final newInfo = {
        'id': myProfile.id,
        'email': myProfile.email,
        'fullName': myProfile.fullName,
        'role': myProfile.role, // Role mới cập nhật (quan trọng)
        'mobileNumber': myProfile.phone,
        'dateOfBirth': myProfile.dateOfBirth,
        'avatarUrl': myProfile.avatarUrl,
        'token': _currentUserInfo['token'], // [QUAN TRỌNG] Giữ nguyên token
      };

      // Lưu đè thông tin mới vào Storage (để lần sau mở app cập nhật đúng)
      await _storage.write(key: 'user_info', value: jsonEncode(newInfo));

      // Cập nhật UI
      if (mounted) {
        setState(() {
          // Cập nhật biến State
          _currentUserInfo = newInfo;

          // Vẽ lại các trang (Menu, Home) dựa trên Role mới
          // Đồng thời UserProfilePage sẽ nhận được _currentUserInfo mới -> Trigger didUpdateWidget
          _updatePages(myProfile.role);
        });

        // Kiểm tra lại quyền HR/Attendance (trong trường hợp vừa bị remove khỏi phòng HR)
        _checkPermission();
      }
    } catch (e) {
      print("Error refreshing profile realtime: $e");
    }
  }

  // 5. HÀM DỰNG DANH SÁCH TRANG
  void _updatePages(String role) {
    _pages = [
      _buildHomeByRole(role),
      _buildMenuPage(role),
      UserProfilePage(
        userInfo: _currentUserInfo,
      ), // Profile luôn nhận data mới nhất
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: IndexedStack(index: _currentIndex, children: _pages),
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
          icon: PhosphorIconsFill.chartLineUp, // Icon biểu đồ
          color: const Color(0xFFE11D48), // Màu đỏ hồng nổi bật
          route: '/analytics', // Dẫn tới route bạn đã khai báo ở main.dart
          width: itemWidth,
        ),
      ],
    );
  }

  // --- MENU CÔNG TY (PHÂN QUYỀN) ---
  Widget _buildCompanyMenu(
    BuildContext context,
    BoxConstraints constraints,
    String role,
  ) {
    final double itemWidth = (constraints.maxWidth - 16) / 2;

    // Check quyền nhân viên phòng HR (Admin hoặc có cờ _canAccessHrAttendance)
    bool isHrPersonnel =
        (role == 'COMPANY_ADMIN' ||
        role == 'HR_MANAGER' ||
        _canAccessHrAttendance);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // 1. My Requests (Ai cũng có)
        _buildMenuItem(
          context,
          title: 'My Requests',
          icon: PhosphorIconsFill.fileText,
          color: const Color(0xFF3B82F6),
          route: '/my_requests',
          width: itemWidth,
        ),

        // 2. Request Management (Admin, Manager, HR Staff)
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

        // 3. HR Management (Chỉ Admin và Manager)
        if (role == 'COMPANY_ADMIN' || role == 'MANAGER')
          _buildMenuItem(
            context,
            title: 'HR Management',
            icon: PhosphorIconsFill.usersThree,
            color: const Color(0xFF8B5CF6),
            route: '/employees',
            width: itemWidth,
          ),

        // 4. Personal Notes
        _buildMenuItem(
          context,
          title: 'Personal Notes',
          icon: PhosphorIconsRegular.notePencil,
          color: const Color(0xFFFFB74D),
          route: '/notes',
          width: itemWidth,
        ),

        // 5. Task Management
        _buildMenuItem(
          context,
          title: 'Task Management',
          icon: PhosphorIconsFill.checkSquare,
          color: const Color(0xFF10B981),
          route: '/tasks',
          arguments: role,
          width: itemWidth,
        ),

        // 6. Attendance
        _buildMenuItem(
          context,
          title: 'Attendance',
          icon: PhosphorIconsFill.mapPin,
          color: const Color(0xFFEC4899),
          route: '/attendance',
          width: itemWidth,
        ),

        // 7. HR Attendance (Báo cáo chấm công)
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

        // 8. Company Profile
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
              () {
                Navigator.pushNamed(context, route, arguments: arguments);
              },
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

  // Hàm chuyển đổi tên Role sang tên hiển thị đẹp hơn
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
        return rawRole; // Trường hợp khác giữ nguyên
    }
  }
}

// Widget Floating Action Button AI
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FadeTransition(
          opacity: _bubbleAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(_bubbleAnimation),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF2260FF).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _currentMessage,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Inter',
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
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
