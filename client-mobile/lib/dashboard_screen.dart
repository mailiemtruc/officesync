import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/config/app_colors.dart';

// Import các trang Home
import 'features/core_service/presentation/pages/staff_home_view.dart';
import 'features/core_service/presentation/pages/manager_home_view.dart';
import 'features/core_service/presentation/pages/director_home_view.dart';
import 'features/core_service/presentation/pages/admin_home_view.dart';

// --- THÊM IMPORT USER PROFILE PAGE ---
// Dựa trên ảnh cấu trúc thư mục bạn gửi
import 'features/hr_service/presentation/pages/user_profile_page.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const DashboardScreen({super.key, required this.userInfo});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // Hàm logout này có thể được truyền xuống Profile nếu cần,
  // nhưng hiện tại UserProfilePage đang tự xử lý UI Logout.
  Future<void> _handleLogout() async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userInfo['role'] ?? 'STAFF';

    // Danh sách các trang cho BottomNavigationBar
    final List<Widget> pages = [
      // Tab 0: Home (Dựa trên Role)
      _buildHomeByRole(role),

      // Tab 1: Menu
      const Center(child: Text("Menu (Đang phát triển)")),

      // Tab 2: Profile (Đã thay thế widget cũ bằng trang UserProfilePage)
      const UserProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      // SafeArea chỉ bọc body để tránh bị che bởi tai thỏ/camera
      body: pages[_currentIndex],
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
    switch (role) {
      case 'SUPER_ADMIN':
        return const AdminHomeView();
      case 'COMPANY_ADMIN':
        return const DirectorHomeView();
      case 'MANAGER':
        return const ManagerHomeView();
      case 'STAFF':
      default:
        return const StaffHomeView();
    }
  }
}
