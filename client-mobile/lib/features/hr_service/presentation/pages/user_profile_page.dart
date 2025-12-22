import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'change_password_page.dart';
import '../../../../core/config/app_colors.dart';
import 'edit_profile_page.dart';

// Import Repository & Model
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/models/employee_model.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const UserProfilePage({super.key, this.userInfo = const {}});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  EmployeeModel? _detailedEmployee;
  bool _isLoadingProfile = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchEmployeeDetail();
  }

  // Hàm format ngày (yyyy-MM-dd -> dd/MM/yyyy)
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'N/A') return 'N/A';
    try {
      if (dateStr.startsWith('[')) {
        final parts = dateStr
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',');
        if (parts.length >= 3) {
          final year = int.parse(parts[0].trim());
          final month = int.parse(parts[1].trim());
          final day = int.parse(parts[2].trim());
          return DateFormat('dd/MM/yyyy').format(DateTime(year, month, day));
        }
      }
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  // Hàm lấy ID người dùng an toàn
  Future<String?> _getUserIdSafe() async {
    if (widget.userInfo.containsKey('id') && widget.userInfo['id'] != null) {
      return widget.userInfo['id'].toString();
    }
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return userMap['id']?.toString();
      }
    } catch (e) {
      print("Error reading storage: $e");
    }
    return null;
  }

  Future<void> _fetchEmployeeDetail() async {
    setState(() => _isLoadingProfile = true);
    try {
      final String? userId = await _getUserIdSafe();

      if (userId == null) {
        _handleLogout();
        return;
      }

      final repo = EmployeeRepositoryImpl(
        remoteDataSource: EmployeeRemoteDataSource(),
      );

      final employees = await repo.getEmployees(userId);

      String? emailToFind = widget.userInfo['email'];
      if (emailToFind == null) {
        final foundById = employees.firstWhere(
          (e) => e.id == userId,
          orElse: () => EmployeeModel(
            id: userId,
            fullName: 'Unknown',
            email: 'N/A',
            phone: '',
            dateOfBirth: '',
            role: 'STAFF',
          ),
        );
        if (mounted) {
          setState(() {
            _detailedEmployee = foundById;
          });
        }
      } else {
        final found = employees.firstWhere(
          (e) => e.email == emailToFind,
          orElse: () => EmployeeModel(
            id: userId,
            fullName: 'Unknown',
            email: emailToFind,
            phone: '',
            dateOfBirth: '',
            role: 'STAFF',
          ),
        );
        if (mounted) {
          setState(() {
            _detailedEmployee = found;
          });
        }
      }
    } catch (e) {
      print("Error fetching profile detail: $e");
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _storage.deleteAll();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      print("Lỗi khi đăng xuất: $e");
    }
  }

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
                onTap: () => Navigator.pop(context),
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
                onTap: () => Navigator.pop(context),
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
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

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
            mainAxisSize: MainAxisSize.min,
            children: [
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
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC9D5FF),
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
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleLogout();
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        _detailedEmployee?.fullName ?? widget.userInfo['fullName'] ?? 'User';
    final role =
        _detailedEmployee?.role ?? widget.userInfo['role'] ?? 'Employee';

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
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/dashboard',
              (route) => false,
            );
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
                      fullName: fullName,
                      role: role,
                      onCameraTap: () => _showImagePickerOptions(context),
                    ),
                    const SizedBox(height: 24),

                    _isLoadingProfile
                        ? const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          )
                        : _InfoSection(
                            userInfo: widget.userInfo,
                            detailedEmployee: _detailedEmployee,
                            dateFormatter: _formatDate,
                            // [SỬA LỖI 1] Truyền hàm reload xuống để khi edit xong thì gọi
                            onRefresh: _fetchEmployeeDetail,
                          ),

                    const SizedBox(height: 24),
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

class _HeaderSection extends StatelessWidget {
  final VoidCallback? onCameraTap;
  final String fullName;
  final String role;

  const _HeaderSection({
    this.onCameraTap,
    required this.fullName,
    required this.role,
  });

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
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                color: const Color(0xFFE2E8F0),
              ),
              child: const Icon(Icons.person, size: 60, color: Colors.grey),
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
        Text(
          fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role,
          style: const TextStyle(
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
  final Map<String, dynamic> userInfo;
  final EmployeeModel? detailedEmployee;
  final String Function(String?) dateFormatter;
  final VoidCallback onRefresh; // [SỬA LỖI 2] Thêm biến hứng callback

  const _InfoSection({
    required this.userInfo,
    this.detailedEmployee,
    required this.dateFormatter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final email = detailedEmployee?.email ?? userInfo['email'] ?? 'N/A';
    final phone = detailedEmployee?.phone ?? userInfo['mobileNumber'] ?? 'N/A';
    final rawDob = detailedEmployee?.dateOfBirth ?? userInfo['dateOfBirth'];
    final formattedDob = dateFormatter(rawDob);
    final empCodeDisplay = detailedEmployee?.employeeCode ?? 'N/A';
    final deptDisplay = detailedEmployee?.departmentName ?? 'Not Assigned';

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
                  value: email,
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.phone(),
                  label: 'Phone',
                  value: phone,
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.buildings(),
                  label: 'Department',
                  value: deptDisplay,
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.identificationCard(),
                  label: 'Employee Code',
                  value: empCodeDisplay,
                ),
                const SizedBox(height: 24),
                _InfoRow(
                  icon: PhosphorIcons.calendarBlank(),
                  label: 'Date of Birth',
                  value: formattedDob,
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
                onTap: () async {
                  // [SỬA LỖI 3] Logic cập nhật thời gian thực
                  // Chuẩn bị data user hiện tại để gửi sang trang edit
                  final currentUser =
                      detailedEmployee ??
                      EmployeeModel(
                        id: userInfo['id'].toString(),
                        fullName: userInfo['fullName'] ?? '',
                        email: userInfo['email'] ?? '',
                        phone: userInfo['phone'] ?? '',
                        dateOfBirth: userInfo['dateOfBirth'] ?? '',
                        role: userInfo['role'] ?? '',
                      );

                  // Chuyển trang và ĐỢI (await) kết quả trả về
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        user: currentUser,
                      ), // Truyền đúng tham số user
                    ),
                  );

                  // Nếu kết quả trả về là true (đã bấm Save changes) -> Gọi reload
                  if (result == true) {
                    onRefresh();
                  }
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              ),
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
                      color: Colors.black, // Giữ nguyên màu gốc
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Change password',
                        style: TextStyle(
                          color: Colors.black, // Giữ nguyên màu gốc
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight(),
                      size: 18,
                      color: Colors.black, // Giữ nguyên màu gốc
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onLogoutTap,
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
