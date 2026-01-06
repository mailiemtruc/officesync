// import 'package:flutter/material.dart';
// import 'package:phosphor_flutter/phosphor_flutter.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'core/config/app_colors.dart';

// // Import các trang Home
// import 'features/core_service/presentation/pages/staff_home_view.dart';
// import 'features/core_service/presentation/pages/manager_home_view.dart';
// import 'features/core_service/presentation/pages/director_home_view.dart';
// import 'features/core_service/presentation/pages/admin_home_view.dart';

// // Import User Profile
// import 'features/hr_service/presentation/pages/user_profile_page.dart';

// // --- THÊM IMPORT CÁC TRANG CHỨC NĂNG ---
// // (Lưu ý: Hãy đảm bảo đường dẫn import đúng với cấu trúc thư mục của bạn)
// import 'features/hr_service/presentation/pages/my_requests_page.dart';
// import 'features/hr_service/presentation/pages/manager_request_list_page.dart';
// import 'features/hr_service/presentation/pages/employee_list_page.dart';

// class DashboardScreen extends StatefulWidget {
//   final Map<String, dynamic> userInfo;

//   const DashboardScreen({super.key, required this.userInfo});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   int _currentIndex = 0;

//   @override
//   Widget build(BuildContext context) {
//     final String role = widget.userInfo['role'] ?? 'STAFF';

//     // Danh sách các trang cho BottomNavigationBar
//     final List<Widget> pages = [
//       // Tab 0: Home
//       _buildHomeByRole(role),

//       // Tab 1: Menu (Đã cập nhật giao diện)
//       _buildMenuPage(role),

//       // Tab 2: Profile
//       const UserProfilePage(),
//     ];

//     return Scaffold(
//       backgroundColor: const Color(0xFFF9F9F9),
//       body: pages[_currentIndex],
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 10,
//               offset: const Offset(0, -5),
//             ),
//           ],
//         ),
//         child: BottomNavigationBar(
//           backgroundColor: Colors.white,
//           currentIndex: _currentIndex,
//           onTap: (index) => setState(() => _currentIndex = index),
//           selectedItemColor: AppColors.primary,
//           unselectedItemColor: Colors.grey,
//           showUnselectedLabels: true,
//           type: BottomNavigationBarType.fixed,
//           selectedLabelStyle: const TextStyle(
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w600,
//             fontSize: 12,
//           ),
//           unselectedLabelStyle: const TextStyle(
//             fontFamily: 'Inter',
//             fontWeight: FontWeight.w500,
//             fontSize: 12,
//           ),
//           items: [
//             BottomNavigationBarItem(
//               icon: Icon(PhosphorIconsRegular.house),
//               activeIcon: Icon(PhosphorIconsFill.house),
//               label: 'Home',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(PhosphorIconsRegular.squaresFour),
//               activeIcon: Icon(PhosphorIconsFill.squaresFour),
//               label: 'Menu',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(PhosphorIconsRegular.user),
//               activeIcon: Icon(PhosphorIconsFill.user),
//               label: 'Profile',
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildHomeByRole(String role) {
//     switch (role) {
//       case 'SUPER_ADMIN':
//         return const AdminHomeView();
//       case 'COMPANY_ADMIN':
//         return const DirectorHomeView();
//       case 'MANAGER':
//         return const ManagerHomeView();
//       case 'STAFF':
//       default:
//         return const StaffHomeView();
//     }
//   }

//   // --- XÂY DỰNG GIAO DIỆN MENU ---
//   Widget _buildMenuPage(String role) {
//     return SafeArea(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Menu',
//               style: TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.primary,
//                 fontFamily: 'Inter',
//               ),
//             ),
//             const SizedBox(height: 24),

//             // Grid các chức năng
//             LayoutBuilder(
//               builder: (context, constraints) {
//                 return Wrap(
//                   spacing: 16,
//                   runSpacing: 16,
//                   children: [
//                     // 1. My Requests (Ai cũng thấy)
//                     _buildMenuItem(
//                       context,
//                       title: 'My Requests',
//                       icon: PhosphorIconsFill.fileText,
//                       color: const Color(0xFF3B82F6), // Xanh dương
//                       route: '/my_requests',
//                       width:
//                           (constraints.maxWidth - 16) / 2, // Chia đôi màn hình
//                     ),

//                     // 2. Request Management (Chỉ Manager & Admin thấy)
//                     if (role == 'MANAGER' || role == 'COMPANY_ADMIN')
//                       _buildMenuItem(
//                         context,
//                         title: 'Request Management',
//                         icon: PhosphorIconsFill.clipboardText,
//                         color: const Color(0xFFF97316), // Cam
//                         route: '/manager_requests',
//                         width: (constraints.maxWidth - 16) / 2,
//                       ),

//                     // 3. HR Management (Chỉ Admin thấy)
//                     if (role == 'COMPANY_ADMIN' || role == 'SUPER_ADMIN')
//                       _buildMenuItem(
//                         context,
//                         title: 'HR Management',
//                         icon: PhosphorIconsFill.usersThree,
//                         color: const Color(0xFF8B5CF6), // Tím
//                         route: '/employees',
//                         width: (constraints.maxWidth - 16) / 2,
//                       ),
//                   ],
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Widget con cho từng ô Menu
//   Widget _buildMenuItem(
//     BuildContext context, {
//     required String title,
//     required IconData icon,
//     required Color color,
//     required String route,
//     required double width,
//   }) {
//     return Container(
//       width: width,
//       height: 140, // Chiều cao cố định cho đẹp
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Material(
//         color: Colors.transparent,
//         borderRadius: BorderRadius.circular(20),
//         child: InkWell(
//           onTap: () {
//             Navigator.pushNamed(context, route);
//           },
//           borderRadius: BorderRadius.circular(20),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(icon, color: color, size: 28),
//                 ),
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF1E293B),
//                     fontFamily: 'Inter',
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  @override
  void initState() {
    super.initState();
    final String role = widget.userInfo['role'] ?? 'STAFF';

    _pages = [
      _buildHomeByRole(role),
      _buildMenuPage(role),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),

      // Sử dụng IndexedStack để giữ trạng thái các trang
      body: IndexedStack(index: _currentIndex, children: _pages),

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

  // --- XÂY DỰNG GIAO DIỆN MENU ---
  Widget _buildMenuPage(String role) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    // 1. My Requests (Luôn hiện)
                    _buildMenuItem(
                      context,
                      title: 'My Requests',
                      icon: PhosphorIconsFill.fileText,
                      color: const Color(0xFF3B82F6),
                      route: '/my_requests',
                      width: (constraints.maxWidth - 16) / 2,
                    ),

                    // 2. Request Management (ĐÃ BỎ ĐIỀU KIỆN IF - LUÔN HIỆN)
                    _buildMenuItem(
                      context,
                      title: 'Request Management',
                      icon: PhosphorIconsFill.clipboardText,
                      color: const Color(0xFFF97316),
                      route: '/manager_requests',
                      width: (constraints.maxWidth - 16) / 2,
                    ),

                    // 3. HR Management (ĐÃ BỎ ĐIỀU KIỆN IF - LUÔN HIỆN)
                    _buildMenuItem(
                      context,
                      title: 'HR Management',
                      icon: PhosphorIconsFill.usersThree,
                      color: const Color(0xFF8B5CF6),
                      route: '/employees',
                      width: (constraints.maxWidth - 16) / 2,
                    ),

                    // 4. Personal Notes (Mục mới)
                    _buildMenuItem(
                      context,
                      title: 'Personal Notes',
                      // Dùng Icon notePencil hoặc note cho hợp ngữ cảnh
                      icon: PhosphorIconsRegular.notePencil,
                      // Màu vàng cam nhạt
                      color: const Color(0xFFFFB74D),
                      route:
                          '/notes', // Đảm bảo route này đã khai báo ở main.dart
                      width: itemWidth,
                    ),

                    // ======================= TASK_SERVICE ==============================
                    _buildMenuItem(
                      context,
                      title: 'Task Management',
                      icon: PhosphorIconsFill.checkSquare,
                      color: const Color(0xFF10B981), // Màu xanh lá
                      route: '/tasks',
                      arguments: role,
                      width: itemWidth,
                    ),

                    // ======================= TASK_SERVICE ==============================
                    _buildMenuItem(
                      context,
                      title: 'Attendance', // Chấm công
                      icon: PhosphorIconsFill.mapPin, // Icon định vị check-in
                      color: const Color(0xFFEC4899), // Màu Hồng
                      route:
                          '/attendance', // Route sang màn hình AttendanceScreen
                      width: itemWidth,
                    ),

                    if (role == 'COMPANY_ADMIN' ||
                        role == 'MANAGER' ||
                        role == 'SUPER_ADMIN')
                      _buildMenuItem(
                        context,
                        title: 'HR Attendance', // Bảng công tổng hợp
                        icon: PhosphorIconsFill.chartBar, // Icon biểu đồ
                        color: Colors.indigo,
                        route: '/manager_attendance', // Route mới
                        width: itemWidth,
                        arguments: role, // Truyền role sang màn hình quản lý
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
    required double width,
    Object? arguments, // Tham số này đã được khai báo
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
          onTap: () {
            // [ĐÃ SỬA] Truyền arguments vào đây
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
