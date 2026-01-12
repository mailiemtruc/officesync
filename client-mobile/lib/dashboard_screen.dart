import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'core/config/app_colors.dart';

// Import các trang Home
import 'features/core_service/presentation/pages/staff_home_view.dart';
import 'features/core_service/presentation/pages/manager_home_view.dart';
import 'features/core_service/presentation/pages/director_home_view.dart';
import 'features/core_service/presentation/pages/admin_home_view.dart';

// Import User Profile
import 'features/hr_service/presentation/pages/user_profile_page.dart';

// ✅ [THÊM DÒNG NÀY] Import service thông báo
import 'features/notification_service/notification_service.dart';

import 'features/hr_service/data/datasources/employee_remote_data_source.dart';

import 'features/ai_service/presentation/pages/ai_chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const DashboardScreen({super.key, required this.userInfo});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // [SỬA LỖI] Dùng IndexedStack để giữ trạng thái trang, tránh reload khi chuyển tab
  late List<Widget> _pages;
  bool _canAccessHrAttendance = false;

  @override
  void initState() {
    super.initState();
    final String role = widget.userInfo['role'] ?? 'STAFF';

    _pages = [
      _buildHomeByRole(role),
      _buildMenuPage(),
      UserProfilePage(userInfo: widget.userInfo),
    ];
    // 2. Logic mới: Đăng ký nhận thông báo (THÊM VÀO ĐÂY)
    try {
      // Lấy ID user, nếu null thì mặc định là 0
      int userId = int.tryParse(widget.userInfo['id'].toString()) ?? 0;

      if (userId > 0) {
        // Gọi hàm đăng ký token với Server
        NotificationService().initNotifications(userId);
        print("--> Đã gọi initNotifications cho user $userId");
      } else {
        print("--> User ID không hợp lệ, bỏ qua đăng ký thông báo");
      }
    } catch (e) {
      print("--> Lỗi khi khởi tạo thông báo: $e");
    }
    _checkPermission();
  }

  // [MỚI] Hàm logic kiểm tra quyền từ Server
  Future<void> _checkPermission() async {
    final String role = widget.userInfo['role'] ?? 'STAFF';

    // Trường hợp 1: Nếu là Admin/Super Admin -> Luôn cho phép
    if (role == 'COMPANY_ADMIN') {
      if (mounted) {
        setState(() {
          _canAccessHrAttendance = true;
          _updatePages(role);
        });
      }
      return;
    }

    // Trường hợp 2: Nếu là Manager -> Cần hỏi Server xem phòng ban có phải là HR không
    if (role == 'MANAGER' || role == 'STAFF') {
      int userId = int.tryParse(widget.userInfo['id'].toString()) ?? 0;

      // Gọi API qua DataSource
      final dataSource = EmployeeRemoteDataSource();
      final canAccess = await dataSource.checkHrPermission(userId);

      if (mounted) {
        setState(() {
          _canAccessHrAttendance = canAccess;
          _updatePages(role); // Cập nhật lại giao diện
        });
      }
    } else {
      // Các role khác (nếu có) -> Chặn
      if (mounted) {
        setState(() {
          _canAccessHrAttendance = false;
          _updatePages(role);
        });
      }
    }
  }

  // Hàm hỗ trợ cập nhật lại danh sách trang (để Menu nhận biến _canAccessHrAttendance mới)
  void _updatePages(String role) {
    _pages = [
      _buildHomeByRole(role),
      _buildMenuPage(),
      UserProfilePage(userInfo: widget.userInfo),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),

      // Sử dụng IndexedStack để giữ trạng thái các trang
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
    // 1. Lấy ID an toàn
    int myId = int.tryParse(widget.userInfo['id'].toString()) ?? 0;

    switch (role) {
      case 'SUPER_ADMIN':
        return AdminHomeView(currentUserId: myId); // 👈 Truyền ID vào
      case 'COMPANY_ADMIN':
        return DirectorHomeView(currentUserId: myId); // (Cái này đã làm rồi)
      case 'MANAGER':
        return ManagerHomeView(currentUserId: myId); // 👈 Truyền ID vào
      case 'STAFF':
      default:
        // Nếu bạn có file StaffHomeView thì cũng làm tương tự nhé, tạm thời tôi để code cũ
        return StaffHomeView(currentUserId: myId);
    }
  }

  // ===========================================================================
  // 1. SỬA HÀM _buildMenuPage ĐỂ PHÂN LOẠI MENU
  // ===========================================================================
  Widget _buildMenuPage() {
    // Lấy role từ userInfo được truyền vào Dashboard
    final String role = widget.userInfo['role'] ?? 'STAFF';

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
                // Hiển thị Role hiện tại để dễ debug
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
                    role,
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
                // 👇 TÁCH LOGIC TẠI ĐÂY
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

  // ===========================================================================
  // 2. MENU DÀNH RIÊNG CHO SUPER ADMIN (QUẢN TRỊ TOÀN APP)
  // ===========================================================================
  Widget _buildSuperAdminMenu(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    // Chia đôi chiều rộng màn hình để xếp 2 ô 1 hàng
    final double itemWidth = (constraints.maxWidth - 16) / 2;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        // 1. Quản lý danh sách công ty (Core Feature của Admin)
        _buildMenuItem(
          context,
          title: 'Manage Companies',
          icon: PhosphorIconsFill.buildings,
          color: const Color(0xFF2563EB), // Xanh đậm chuyên nghiệp
          route:
              '/admin_companies', // Cần đảm bảo route này đã khai báo trong main.dart
          width: itemWidth,
          // Nếu chưa có route riêng, có thể điều hướng về Tab Home (index 0) nơi có list công ty
          onTapOverride: () {
            setState(() => _currentIndex = 0);
          },
        ),

        // 2. Thống kê hệ thống
        _buildMenuItem(
          context,
          title: 'System Stats',
          icon: PhosphorIconsFill.chartLineUp,
          color: const Color(0xFF059669), // Xanh lá đậm
          route: '/system_stats', // Route giả định
          width: itemWidth,
        ),

        // 3. Quản lý User toàn cục
        _buildMenuItem(
          context,
          title: 'Global Users',
          icon: PhosphorIconsFill.usersFour,
          color: const Color(0xFFD97706), // Vàng cam đậm
          route: '/global_users', // Route giả định
          width: itemWidth,
        ),

        // 4. Cấu hình ứng dụng
        _buildMenuItem(
          context,
          title: 'App Settings',
          icon: PhosphorIconsFill.gear,
          color: const Color(0xFF475569), // Xám xanh
          route: '/app_settings', // Route giả định
          width: itemWidth,
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. MENU DÀNH CHO CÔNG TY (LOGIC CŨ CỦA BẠN)
  // ===========================================================================
  Widget _buildCompanyMenu(
    BuildContext context,
    BoxConstraints constraints,
    String role,
  ) {
    final double itemWidth = (constraints.maxWidth - 16) / 2;

    // Logic kiểm tra quyền HR (Giữ nguyên logic cũ của bạn)
    bool canAccessHrAttendance =
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

        // 2. Request Management (Cho Manager/Admin)
        _buildMenuItem(
          context,
          title: 'Request Management',
          icon: PhosphorIconsFill.clipboardText,
          color: const Color(0xFFF97316),
          route: '/manager_requests',
          width: itemWidth,
        ),

        // 3. HR Management (Quản lý nhân sự)
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

        // 5. Task Management (Truyền role vào để phân quyền bên trong màn hình Task)
        _buildMenuItem(
          context,
          title: 'Task Management',
          icon: PhosphorIconsFill.checkSquare,
          color: const Color(0xFF10B981),
          route: '/tasks',
          arguments: role,
          width: itemWidth,
        ),

        // 6. Attendance (Chấm công cá nhân)
        _buildMenuItem(
          context,
          title: 'Attendance',
          icon: PhosphorIconsFill.mapPin,
          color: const Color(0xFFEC4899),
          route: '/attendance',
          width: itemWidth,
        ),

        // 7. HR Attendance (Xem báo cáo chấm công)
        if (canAccessHrAttendance)
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

        // 8. Company Profile (Chỉ Company Admin được sửa thông tin công ty)
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

  // ===========================================================================
  // 4. CẬP NHẬT WIDGET Ô MENU (HỖ TRỢ ONTAP MỞ RỘNG)
  // ===========================================================================
  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required double width,
    Object? arguments,
    VoidCallback? onTapOverride, // Thêm tham số này
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
          // Nếu có onTapOverride thì dùng, không thì pushNamed mặc định
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
}

// --- DÁN ĐÈ CÁI NÀY VÀO CUỐI FILE dashboard_screen.dart ---

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

  // [PRO] Danh sách câu thoại ngắn gọn, đúng trọng tâm công việc
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

    // 1. Animation Bong bóng: Mượt mà, dứt khoát (Không nảy tưng tưng)
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Tốc độ vừa phải
    );

    _bubbleAnimation = CurvedAnimation(
      parent: _bubbleController,
      curve:
          Curves.easeOutBack, // Hiệu ứng trượt ra và khóa vị trí (Professional)
      reverseCurve: Curves.easeInBack,
    );

    // 2. Animation Nút: Nhịp thở nhẹ nhàng (Subtle Pulse)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Chậm rãi hơn
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

    // Hiện lâu hơn một chút để người dùng kịp đọc
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
        // 1. MESSAGE BUBBLE (Premium Look)
        FadeTransition(
          opacity: _bubbleAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2), // Trượt nhẹ từ dưới lên
              end: Offset.zero,
            ).animate(_bubbleAnimation),

            child: Container(
              margin: const EdgeInsets.only(
                bottom: 12,
                right: 2,
              ), // Căn chỉnh lề chuẩn
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                // Bo tròn hoàn toàn (Pill Shape) nhìn hiện đại hơn
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  // Lớp bóng 1: Mờ, rộng (Ambient)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  // Lớp bóng 2: Đậm, hẹp (Direct)
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
                  color: Color(
                    0xFF334155,
                  ), // Màu xám xanh đậm (Slate 700) - Sang hơn đen tuyền
                  fontWeight: FontWeight.w500, // Medium weight
                  fontSize: 14,
                  fontFamily: 'Inter',
                  letterSpacing: 0.3, // Giãn chữ nhẹ cho thoáng
                ),
              ),
            ),
          ),
        ),

        // 2. AI FAB BUTTON (Glow Effect)
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vòng Glow lan tỏa mờ ảo
              _buildSubtlePulse(),

              // Nút chính
              GestureDetector(
                onTap: widget.onPressed,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    // Gradient chéo nhẹ nhàng
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
                    Icons
                        .smart_toy_outlined, // Dùng Outlined icon nhìn thanh thoát hơn
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              // [Chi tiết nhỏ] Chấm xanh Online (Status Dot)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Green Emerald
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

  Widget _buildSubtlePulse() {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 0.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.5).animate(
          // Lan tỏa vừa phải
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(
              0xFF3B82F6,
            ).withOpacity(0.2), // Màu nền mờ thay vì viền
          ),
        ),
      ),
    );
  }
}
