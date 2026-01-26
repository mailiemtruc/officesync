import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:officesync/features/communication_service/data/newsfeed_api.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import 'package:officesync/features/notification_service/notification_service.dart';
import 'change_password_page.dart';
import '../../../../core/config/app_colors.dart';
import 'edit_profile_page.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/models/employee_model.dart';
import '../../../../core/services/websocket_service.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/utils/user_update_event.dart';
import '../../../../core/services/security_service.dart';
import 'package:officesync/features/chat_service/data/chat_api.dart';

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

  // biến lưu file ảnh local để hiển thị ngay lập tức
  File? _localAvatarFile;

  final ImagePicker _picker = ImagePicker();
  final _storage = const FlutterSecureStorage();
  final _newsfeedApi = NewsfeedApi();
  final _chatApi = ChatApi();
  late final EmployeeRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );
    _fetchEmployeeDetail();
  }

  // Hàm này để lắng nghe thay đổi từ Dashboard (Cha) truyền xuống
  @override
  void didUpdateWidget(covariant UserProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Nếu dữ liệu từ Dashboard thay đổi (do Socket cập nhật)
    if (widget.userInfo != oldWidget.userInfo) {
      print("--> [Profile] Updating UI from Parent Data (No API Call)");

      //  Update thẳng vào State, KHÔNG gọi API, KHÔNG hiện loading
      _updateLocalStateFromUserInfo();
    }
  }

  // Hàm helper để convert Map -> Model
  void _updateLocalStateFromUserInfo() {
    if (widget.userInfo.isEmpty) return;

    setState(() {
      // Cập nhật hoặc tạo mới model từ dữ liệu mới nhất
      _detailedEmployee = EmployeeModel(
        id: widget.userInfo['id']?.toString() ?? _detailedEmployee?.id ?? '',
        fullName:
            widget.userInfo['fullName'] ?? _detailedEmployee?.fullName ?? '',
        email: widget.userInfo['email'] ?? _detailedEmployee?.email ?? '',
        phone:
            widget.userInfo['phone'] ??
            widget.userInfo['mobileNumber'] ??
            _detailedEmployee?.phone ??
            '',
        dateOfBirth:
            widget.userInfo['dateOfBirth'] ??
            _detailedEmployee?.dateOfBirth ??
            '',
        role: widget.userInfo['role'] ?? _detailedEmployee?.role ?? 'STAFF',
        avatarUrl: widget.userInfo['avatarUrl'] ?? _detailedEmployee?.avatarUrl,

        // Lấy dữ liệu mới được Dashboard truyền xuống
        employeeCode:
            widget.userInfo['employeeCode'] ?? _detailedEmployee?.employeeCode,
        departmentName:
            widget.userInfo['departmentName'] ??
            _detailedEmployee?.departmentName,
      );

      // Đảm bảo tắt loading nếu nó đang bật
      _isLoadingProfile = false;
    });
  }

  //  Hàm chuyển đổi Role sang tên hiển thị đẹp
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
    // Chỉ hiện loading toàn trang khi chưa có dữ liệu lần đầu
    if (_detailedEmployee == null) {
      setState(() => _isLoadingProfile = true);
    }
    try {
      final String? userId = await _getUserIdSafe();
      if (userId == null) {
        _handleLogout();
        return;
      }

      final employees = await _repository.getEmployees(userId);

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

  // --- LOGIC UPLOAD ẢNH  ---
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        final file = File(image.path);

        // Hiển thị ảnh ngay lập tức (Optimistic UI)
        setState(() {
          _localAvatarFile = file;
          _isUploading = true;
        });

        // Tiến hành upload
        _uploadAvatar(file);
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _uploadAvatar(File file) async {
    try {
      String fileUrl = await _repository.uploadFile(file);
      print("--> Upload Repository success: $fileUrl");
      await _updateAvatarUrlInProfile(fileUrl);
    } catch (e) {
      print("Upload error: $e");
      if (mounted) {
        setState(() {
          _localAvatarFile = null;
          _isUploading = false;
        });

        CustomSnackBar.show(
          context,
          title: "Upload Failed",
          message: e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  Future<void> _updateAvatarUrlInProfile(String avatarUrl) async {
    if (_detailedEmployee == null) return;
    try {
      final success = await _repository.updateEmployee(
        _detailedEmployee!.id ?? "",
        _detailedEmployee!.id ?? "",
        _detailedEmployee!.fullName,
        _detailedEmployee!.phone,
        _detailedEmployee!.dateOfBirth,
        avatarUrl: avatarUrl,
      );

      if (success) {
        print("--> Update HR Profile success!");
        await _updateLocalUserStorage(avatarUrl);

        //  Cập nhật ngay lập tức vào UI (Optimistic Update)
        if (mounted) {
          setState(() {
            _detailedEmployee = EmployeeModel(
              id: _detailedEmployee!.id,
              fullName: _detailedEmployee!.fullName,
              email: _detailedEmployee!.email,
              phone: _detailedEmployee!.phone,
              dateOfBirth: _detailedEmployee!.dateOfBirth,
              role: _detailedEmployee!.role,
              employeeCode: _detailedEmployee!.employeeCode,
              departmentName: _detailedEmployee!.departmentName,
              avatarUrl: avatarUrl,
            );

            // Xóa file local và tắt loading upload
            _localAvatarFile = null;
            _isUploading = false;
          });

          CustomSnackBar.show(
            context,
            title: "Success",
            message: "Profile picture updated successfully!",
            isError: false,
          );
        }

        // --- CÁC TÁC VỤ NGẦM  ---
        _chatApi.updateChatProfile(avatarUrl: avatarUrl).catchError((e) {
          print("--> Lỗi Chat Service: $e");
        });

        UserUpdateEvent().notify();

        _newsfeedApi.syncUserAvatar(avatarUrl).catchError((e) {
          print("⚠️ Sync Newsfeed error: $e");
        });
      }
    } catch (e) {
      print("Error saving profile: $e");
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _updateLocalUserStorage(String newAvatarUrl) async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        userMap['avatarUrl'] = newAvatarUrl;
        await _storage.write(key: 'user_info', value: jsonEncode(userMap));
      }
    } catch (e) {
      print("Error updating local storage: $e");
    }
  }

  // --- UI & DIALOGS ---
  Future<void> _handleLogout() async {
    try {
      // --- XÓA TOKEN NOTIFICATION (Fire-and-forget) ---
      String? userIdStr = await _getUserIdSafe();
      if (userIdStr != null) {
        int uid = int.tryParse(userIdStr) ?? 0;
        if (uid > 0) {
          NotificationService().unregisterDevice(uid).catchError((e) {
            print("⚠️ Server Notification đang tắt, không xóa được Token: $e");
          });
          print("--> Đã gửi lệnh hủy Token (Không chờ phản hồi)");
        }
      }
      // -----------------------------------------------------------

      // 1. Xóa Token đăng nhập trong Storage
      await _storage.deleteAll();

      // Gọi hàm này để reset biến _isListening = false bên trong SecurityService.
      // Nếu thiếu, lần đăng nhập sau Socket 8080 sẽ từ chối kết nối lại!
      SecurityService().disconnect();

      // 2. Ngắt kết nối các socket khác (HR, Chat...)
      WebSocketService().disconnect();

      // 3. Chuyển về màn hình Login
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      print("Logout error: $e");
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo (Drag Handle)
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 1. Take a photo
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.camera),
                  splashColor: Colors.grey.withOpacity(0.2),
                  highlightColor: Colors.grey.withOpacity(0.1),
                  child: ListTile(
                    leading: Icon(
                      PhosphorIcons.camera(PhosphorIconsStyle.regular),
                      color: AppColors.primary,
                      size: 24,
                    ),
                    title: const Text(
                      'Take a photo',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Choose from gallery
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _pickImage(ImageSource.gallery),
                  splashColor: Colors.grey.withOpacity(0.2),
                  highlightColor: Colors.grey.withOpacity(0.1),
                  child: ListTile(
                    leading: Icon(
                      PhosphorIcons.image(PhosphorIconsStyle.regular),
                      color: AppColors.primary,
                      size: 24,
                    ),
                    title: const Text(
                      'Choose from gallery',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Cancel (Giữ nguyên hiệu ứng màu đỏ)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  splashColor: const Color(0xFFFF0000).withOpacity(0.1),
                  highlightColor: const Color(0xFFFF0000).withOpacity(0.05),
                  child: ListTile(
                    leading: Icon(
                      PhosphorIcons.x(PhosphorIconsStyle.regular),
                      color: const Color(0xFFFF0000),
                      size: 24,
                    ),
                    title: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFFF0000),
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
      isScrollControlled: true,
      builder: (context) {
        return ConfirmBottomSheet(
          title: 'Log Out',
          message: 'Are you sure you want to log out?',
          confirmText: 'Log out',
          cancelText: 'Cancel',
          confirmColor: AppColors.primary,
          onConfirm: () {
            Navigator.pop(context); // Đóng BottomSheet trước
            _handleLogout(); // Sau đó thực hiện Logout
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        _detailedEmployee?.fullName ?? widget.userInfo['fullName'] ?? 'User';

    //  Lấy role thô trước
    final rawRole =
        _detailedEmployee?.role ?? widget.userInfo['role'] ?? 'Employee';
    //  Sau đó chuyển đổi qua hàm hiển thị
    final role = _getDisplayRole(rawRole);
    final avatarUrl = _detailedEmployee?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(overscroll: false),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Header
                    const Center(
                      child: Text(
                        'PERSONAL INFORMATION',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      reverseDuration: const Duration(milliseconds: 50),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _isLoadingProfile
                          ? const SkeletonUserProfile(
                              key: ValueKey('profile_skeleton'),
                            )
                          : Column(
                              key: const ValueKey('profile_content'),
                              children: [
                                _HeaderSection(
                                  fullName: fullName,
                                  role: role,
                                  avatarUrl: avatarUrl,
                                  isUploading: _isUploading,
                                  localImage: _localAvatarFile,
                                  onCameraTap: () =>
                                      _showImagePickerOptions(context),
                                ),
                                const SizedBox(height: 24),
                                _InfoSection(
                                  userInfo: widget.userInfo,
                                  detailedEmployee: _detailedEmployee,
                                  dateFormatter: _formatDate,
                                  onRefresh: _fetchEmployeeDetail,
                                ),
                                const SizedBox(height: 24),
                                _ActionSection(
                                  onLogoutTap: () =>
                                      _showLogoutConfirmation(context),
                                ),
                              ],
                            ),
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
  final File? localImage;

  const _HeaderSection({
    super.key,
    this.onCameraTap,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.isUploading = false,
    this.localImage,
  });

  @override
  Widget build(BuildContext context) {
    // Định nghĩa màu sắc thống nhất cho avatar mặc định
    final placeholderBgColor = Colors.grey[200];
    final placeholderIconColor = Colors.grey[400];

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
                color: placeholderBgColor,
              ),
              child: ClipOval(
                child: localImage != null
                    ? Image.file(
                        localImage!,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                        errorBuilder: (context, error, stackTrace) {
                          if (avatarUrl != null && avatarUrl!.isNotEmpty) {
                            return Image.network(
                              avatarUrl!,
                              fit: BoxFit.cover,
                              width: 110,
                              height: 110,
                              errorBuilder: (_, __, ___) => Icon(
                                PhosphorIcons.user(PhosphorIconsStyle.fill),
                                size: 60,
                                color: placeholderIconColor,
                              ),
                            );
                          }
                          return Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            size: 60,
                            color: placeholderIconColor,
                          );
                        },
                      )
                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        avatarUrl!,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                        errorBuilder: (ctx, err, stack) => Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.fill),
                          size: 60,
                          color: placeholderIconColor,
                        ),
                      )
                    : Icon(
                        PhosphorIcons.user(PhosphorIconsStyle.fill),
                        size: 60,
                        color: placeholderIconColor,
                      ),
              ),
            ),

            // Nút Camera
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: isUploading
                    ? Colors.grey
                    : AppColors.primary, // Đổi màu xám nếu đang upload
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  // Nếu đang upload thì khóa nút lại (null) để ko bấm lung tung
                  onTap: isUploading ? null : onCameraTap,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    width: 32,
                    height: 32,
                    child: isUploading
                        // Thay icon máy ảnh bằng cái chấm nhỏ xíu đang nhảy
                        ? const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
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
                  label: 'Employee ID',
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

class SkeletonUserProfile extends StatelessWidget {
  const SkeletonUserProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      period: const Duration(milliseconds: 2000),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 12),
          // Name & Role
          Container(
            width: 180,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 100,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 32),

          // Info Section giả
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: List.generate(4, (index) {
                // [LOGIC ORGANIC] Độ dài ngẫu nhiên: chẵn thì dài, lẻ thì ngắn
                final double textWidth = index % 2 == 0
                    ? double.infinity
                    : 150.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: textWidth, // Áp dụng độ dài ngẫu nhiên
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          // Action Section giả
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
        ],
      ),
    );
  }
}
