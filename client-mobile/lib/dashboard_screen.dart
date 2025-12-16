import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/config/app_colors.dart';

import 'features/core_service/presentation/pages/staff_home_view.dart';
import 'features/core_service/presentation/pages/manager_home_view.dart';
import 'features/core_service/presentation/pages/director_home_view.dart';
import 'features/core_service/presentation/pages/admin_home_view.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const DashboardScreen({super.key, required this.userInfo});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  Future<void> _handleLogout() async {
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/register', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = widget.userInfo['role'] ?? 'STAFF';

    final List<Widget> pages = [
      _buildHomeByRole(role),
      const Center(child: Text("Menu (Đang phát triển)")),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: pages[_currentIndex]),
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

  Widget _buildProfileTab() {
    final String fullName = widget.userInfo['fullName'] ?? 'User';
    final String email = widget.userInfo['email'] ?? 'No Email';
    final String role = widget.userInfo['role'] ?? 'STAFF';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Icon(
              PhosphorIconsFill.user,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _handleLogout(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                "Log Out",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
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
