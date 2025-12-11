import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import config
import '../../../../core/config/app_colors.dart';
import 'edit_profile_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // 1. Hàm hiện Bottom Sheet chọn ảnh (Camera) - Đã sửa nút Cancel & Icon
  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
          ),
          // --- SỬA LỖI TẠI ĐÂY ---
          // Bọc Column bằng Material trong suốt để hiển thị hiệu ứng ripple
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    PhosphorIcons.camera(PhosphorIconsStyle.regular),
                    color: AppColors.primary,
                    size: 24,
                  ),
                  title: const Text(
                    'Take photo',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Chụp ảnh
                    print("Profile: Chụp ảnh");
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.image(PhosphorIconsStyle.regular),
                    color: AppColors.primary,
                    size: 24,
                  ),
                  title: const Text(
                    'Choose from Library',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Chọn ảnh
                    print("Profile: Chọn thư viện");
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    color: const Color(0xFFFF0000),
                    size: 24,
                  ),
                  title: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFFFF0000),
                      fontSize: 20,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. Hàm hiện Bottom Sheet xác nhận đăng xuất (Log Out)
  void _showLogoutConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Chiều cao tự động
            children: [
              // Tiêu đề
              const Text(
                'Log Out',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              // Nội dung
              const Text(
                'Are you sure you want to log out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),

              // Hai nút bấm: Cancel & Logout
              Row(
                children: [
                  // Nút Cancel (Xám)
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFFC9D5FF,
                          ), // Xám xanh nhạt
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20), // Khoảng cách giữa 2 nút
                  // Nút Logout (Xanh đậm)
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Đóng Bottom Sheet
                          // TODO: Gọi hàm Logout thật (AuthBloc)
                          print("Đã đăng xuất!");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text(
                          'Log out',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10), // Padding bottom
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () {
            // Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'PERSONAL INFORMATION',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(overscroll: false),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _HeaderSection(
                      onCameraTap: () => _showImagePickerOptions(context),
                    ),
                    const SizedBox(height: 24),
                    const _InfoSection(),
                    const SizedBox(height: 24),

                    // Truyền callback Logout vào phần Action
                    _ActionSection(
                      onLogoutTap: () => _showLogoutConfirmation(context),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- CÁC WIDGET CON ---

class _HeaderSection extends StatelessWidget {
  final VoidCallback? onCameraTap;

  const _HeaderSection({this.onCameraTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFF5F5F5), width: 3),
                image: const DecorationImage(
                  image: NetworkImage("https://placehold.co/190x178"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCameraTap,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    width: 32,
                    height: 32,
                    child: Icon(
                      PhosphorIcons.camera(PhosphorIconsStyle.fill),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Nguyen Van A',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Employee',
          style: TextStyle(
            color: Color(0xFF6A6A6A),
            fontSize: 15,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF5F5F5), width: 1),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
            child: Column(
              children: [
                _InfoRow(
                  icon: PhosphorIcons.envelopeSimple(),
                  label: 'Email',
                  value: 'nguyenvana@gmail.com',
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.phone(),
                  label: 'Phone',
                  value: '0909123456',
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.buildings(),
                  label: 'Department',
                  value: 'Business',
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.identificationCard(),
                  label: 'Employee ID',
                  value: '001',
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.calendarBlank(),
                  label: 'Date of Birth',
                  value: '01/10/1997',
                ),
              ],
            ),
          ),
          Positioned(
            top: 15,
            right: 15,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfilePage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  // Thêm callback onLogoutTap
  final VoidCallback? onLogoutTap;

  const _ActionSection({this.onLogoutTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF5F5F5), width: 1),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.lockKey(),
                      color: Colors.black,
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Change password',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight(),
                      size: 18,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),

          // Nút Logout
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onLogoutTap, // GỌI CALLBACK KHI BẤM
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.signOut(),
                      color: const Color(0xFFF30000),
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Log out',
                        style: TextStyle(
                          color: Color(0xFFF30000),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF404040), size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF909090),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
