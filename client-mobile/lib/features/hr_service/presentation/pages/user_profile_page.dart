import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:officesync/features/communication_service/data/newsfeed_api.dart';
//notification
import 'package:officesync/features/notification_service/notification_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'change_password_page.dart';
import '../../../../core/config/app_colors.dart';
import 'edit_profile_page.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/models/employee_model.dart';
// [MỚI] Import WebSocketService để ngắt kết nối
import '../../../../core/services/websocket_service.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const UserProfilePage({super.key, this.userInfo = const {}});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  EmployeeModel? _detailedEmployee;
  bool _isLoadingProfile = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  final _storage = const FlutterSecureStorage();
  final _newsfeedApi = NewsfeedApi();

  @override
  void initState() {
    super.initState();
    _fetchEmployeeDetail();
  }

  // --- HÀM HỖ TRỢ ---
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

  // --- LOGIC LẤY DATA ---
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
      EmployeeModel? found;

      if (emailToFind == null) {
        found = employees.firstWhere(
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
      } else {
        found = employees.firstWhere(
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
      }

      if (mounted) {
        setState(() {
          _detailedEmployee = found;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print("Error fetching profile detail: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // --- LOGIC UPLOAD ẢNH ---
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        _uploadAvatar(File(image.path));
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _uploadAvatar(File file) async {
    setState(() => _isUploading = true);
    try {
      // IP 10.0.2.2 cho Emulator, máy thật dùng IP LAN
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8090/api/files/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        String fileUrl = data['url'];
        print("--> Upload Storage success: $fileUrl");
        await _updateAvatarUrlInProfile(fileUrl);
      } else {
        throw Exception("Upload failed: ${response.body}");
      }
    } catch (e) {
      print("Upload error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        // [TIẾNG ANH]
        SnackBar(
          content: Text("Upload failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateAvatarUrlInProfile(String avatarUrl) async {
    if (_detailedEmployee == null) return;
    try {
      final url = Uri.parse(
        'http://10.0.2.2:8081/api/employees/${_detailedEmployee!.id}',
      );
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fullName": _detailedEmployee!.fullName,
          "phone": _detailedEmployee!.phone,
          "dateOfBirth": _detailedEmployee!.dateOfBirth,
          "avatarUrl": avatarUrl,
        }),
      );

      if (response.statusCode == 200) {
        print("--> Update HR Profile success!");
        // ✅ THÊM DÒNG NÀY: Cập nhật cache ngay lập tức
        await _updateLocalUserStorage(avatarUrl);
        // ✅ 2. [THÊM DÒNG NÀY] Bắn tin sang Communication Service ngay!
        await _newsfeedApi.syncUserAvatar(avatarUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          // [TIẾNG ANH]
          const SnackBar(
            content: Text("Profile picture updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchEmployeeDetail();
      } else {
        if (response.body.contains("No changes detected")) {
          print("No changes detected.");
        } else {
          throw Exception("Update HR failed: ${response.body}");
        }
      }
    } catch (e) {
      print("Error saving profile: $e");
    }
  }

  // ✅ THÊM HÀM NÀY XUỐNG DƯỚI CÙNG
  Future<void> _updateLocalUserStorage(String newAvatarUrl) async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        userMap['avatarUrl'] = newAvatarUrl; // Cập nhật link mới
        await _storage.write(key: 'user_info', value: jsonEncode(userMap));
        print("--> Đã cập nhật Avatar mới vào SecureStorage");
      }
    } catch (e) {
      print("Lỗi cập nhật Storage: $e");
    }
  }

  // --- UI & DIALOGS ---
  // [QUAN TRỌNG] HÀM ĐĂNG XUẤT ĐÃ SỬA
  Future<void> _handleLogout() async {
    try {
      // -----------------------------------------------------------
      // 👇 1. [THÊM MỚI] Gọi API báo Server xóa Token đi
      // -----------------------------------------------------------
      String? userIdStr = await _getUserIdSafe(); // Tận dụng hàm có sẵn của bạn
      if (userIdStr != null) {
        int uid = int.tryParse(userIdStr) ?? 0;
        if (uid > 0) {
          await NotificationService().unregisterDevice(uid);
          print("--> Đã logout và hủy Token thông báo thành công");
        }
      }
      // -----------------------------------------------------------
      // 1. Xóa dữ liệu local
      await _storage.deleteAll();

      // 2. Ngắt kết nối WebSocket
      WebSocketService().disconnect();

      // 3. Chuyển về màn hình đăng nhập
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      print("Logout error: $e");
      // Dù lỗi mạng vẫn cho đăng xuất khỏi App để tránh kẹt
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
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
                // [TIẾNG ANH]
                title: const Text(
                  'Take a photo',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  PhosphorIcons.image(PhosphorIconsStyle.regular),
                  color: AppColors.primary,
                  size: 24,
                ),
                // [TIẾNG ANH]
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(
                  PhosphorIcons.x(PhosphorIconsStyle.regular),
                  color: const Color(0xFFFF0000),
                  size: 24,
                ),
                // [TIẾNG ANH]
                title: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFFFF0000),
                    fontSize: 18,
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
    final avatarUrl = _detailedEmployee?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      // [XÓA] Bỏ AppBar
      body: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(overscroll: false),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                // [SỬA 1] Padding top = 0
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  children: [
                    // [SỬA 2] Khoảng cách chuẩn
                    const SizedBox(height: 20),

                    // [SỬA 3] Custom Header
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            color: AppColors.primary,
                            size: 24,
                          ),
                          // Logic back về Dashboard giữ nguyên
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/dashboard',
                            (route) => false,
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'PERSONAL INFORMATION',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 22, // Giảm size xíu nếu chữ dài
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Header Section (Avatar + Tên) giữ nguyên
                    _HeaderSection(
                      fullName: fullName,
                      role: role,
                      avatarUrl: avatarUrl,
                      isUploading: _isUploading,
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
  final String? avatarUrl;
  final bool isUploading;

  const _HeaderSection({
    this.onCameraTap,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.isUploading = false,
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
              child: ClipOval(
                child: isUploading
                    ? const Padding(
                        padding: EdgeInsets.all(35),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
                      )
                    : const Icon(Icons.person, size: 60, color: Colors.grey),
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
  final VoidCallback onRefresh;

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
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(user: currentUser),
                    ),
                  );
                  if (result == true) onRefresh();
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
