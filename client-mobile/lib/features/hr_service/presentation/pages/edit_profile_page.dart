import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../data/models/employee_model.dart';
import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';

class EditProfilePage extends StatefulWidget {
  final EmployeeModel user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;

  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _currentAvatarUrl; // Lưu URL avatar hiện tại
  // [MỚI] Biến theo dõi xem có thay đổi dữ liệu (đặc biệt là avatar) chưa
  bool _hasUpdates = false;
  late final EmployeeRepositoryImpl _repository;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    // Lấy avatar ban đầu
    _currentAvatarUrl = widget.user.avatarUrl;

    _fullNameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);

    String dobDisplay = "";
    if (widget.user.dateOfBirth.isNotEmpty &&
        widget.user.dateOfBirth != 'N/A') {
      try {
        if (widget.user.dateOfBirth.startsWith('[')) {
          final parts = widget.user.dateOfBirth
              .replaceAll('[', '')
              .replaceAll(']', '')
              .split(',');
          if (parts.length >= 3) {
            final year = int.parse(parts[0].trim());
            final month = int.parse(parts[1].trim());
            final day = int.parse(parts[2].trim());
            dobDisplay = DateFormat(
              'dd/MM/yyyy',
            ).format(DateTime(year, month, day));
          }
        } else {
          DateTime date = DateTime.parse(widget.user.dateOfBirth);
          dobDisplay = DateFormat('dd/MM/yyyy').format(date);
        }
      } catch (_) {
        dobDisplay = widget.user.dateOfBirth;
      }
    }
    _dobController = TextEditingController(text: dobDisplay);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // --- LOGIC 1: AVATAR TỰ ĐỘNG CẬP NHẬT ---

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        // Upload và TỰ ĐỘNG UPDATE Profile ngay
        _uploadAndAutoSaveAvatar(File(image.path));
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // [ĐÃ SỬA] Hàm upload và cập nhật biến _hasUpdates
  Future<void> _uploadAndAutoSaveAvatar(File file) async {
    setState(() => _isUploadingAvatar = true);
    try {
      // 1. Upload ảnh qua Repository
      String newAvatarUrl = await _repository.uploadFile(file);
      print("--> Upload Repository success: $newAvatarUrl");

      // 2. Cập nhật UI tạm thời
      setState(() {
        _currentAvatarUrl = newAvatarUrl;
        _hasUpdates = true; // [QUAN TRỌNG] Đánh dấu là đã có thay đổi
      });

      // 3. Gọi API cập nhật thông tin nhân viên
      await _repository.updateEmployee(
        widget.user.id ?? "",
        widget.user.id ?? "",
        widget.user.fullName,
        widget.user.phone,
        widget.user.dateOfBirth,
        avatarUrl: newAvatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile picture updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Auto-save avatar error: $e");
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update avatar: $msg"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // --- LOGIC 2: BẤM NÚT SAVE MỚI LƯU TEXT ---

  Future<void> _handleSaveChanges() async {
    setState(() => _isLoading = true);

    try {
      // Chuẩn bị ngày sinh từ Input
      String dbDob = "";
      if (_dobController.text.isNotEmpty) {
        try {
          DateTime parsed = DateFormat('dd/MM/yyyy').parse(_dobController.text);
          dbDob = DateFormat('yyyy-MM-dd').format(parsed);
        } catch (_) {}
      }

      // Trong _handleSaveChanges
      final success = await _repository.updateEmployee(
        widget.user.id ?? "", // [MỚI] Tham số 1: Updater ID
        widget.user.id ?? "", // Tham số 2: Target ID
        _fullNameController.text.trim(), // Tham số 3
        _phoneController.text.trim(), // Tham số 4
        dbDob, // Tham số 5
        avatarUrl: _currentAvatarUrl,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile details updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Quay lại và refresh
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        if (msg.contains("Failed to update:")) {
          try {
            String rawJson = msg.replaceAll("Failed to update:", "").trim();
            final decoded = jsonDecode(rawJson);
            if (decoded is Map && decoded.containsKey('message')) {
              msg = decoded['message'];
            }
          } catch (_) {}
        }
        if (msg.contains("No changes detected")) {
          msg = "No changes detected.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: msg.contains("No changes")
                ? Colors.orange
                : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI COMPONENTS ---

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
              // Thanh kéo (Drag Handle) - Đồng bộ
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

              // 1. Take a photo - Đồng bộ hiệu ứng xám
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

              // 2. Choose from gallery - Đồng bộ hiệu ứng xám
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

              // 3. Cancel - Giữ nguyên hiệu ứng đỏ
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

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime(2000);
    if (_dobController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd/MM/yyyy').parse(_dobController.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // [ĐÃ SỬA] Header
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                          color: AppColors.primary,
                          size: 24,
                        ),
                        // [QUAN TRỌNG] Trả về biến _hasUpdates khi nhấn nút Back
                        onPressed: () => Navigator.of(context).pop(_hasUpdates),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'EDIT PROFILE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Avatar Section (Giữ nguyên)
                  _AvatarEditSection(
                    avatarUrl: _currentAvatarUrl,
                    isUploading: _isUploadingAvatar,
                    onCameraTap: () => _showImagePickerOptions(context),
                  ),
                  const SizedBox(height: 40),
                  _buildLabel('Full name'),
                  CustomTextField(
                    controller: _fullNameController,
                    hintText: 'Full Name',
                  ),
                  const SizedBox(height: 30),

                  _buildLabel('Email'),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    readOnly: true,
                    fillColor: const Color(0xFFEAEBEE),
                    suffixIcon: Icon(
                      PhosphorIcons.lock(PhosphorIconsStyle.regular),
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildLabel('Phone'),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: 'Phone',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 30),

                  _buildLabel('Date of birth'),
                  CustomTextField(
                    controller: _dobController,
                    hintText: 'dd/mm/yyyy',
                    readOnly: true,
                    suffixIcon: Icon(
                      PhosphorIcons.calendarBlank(),
                      color: AppColors.primary,
                    ),
                    onTap: () => _selectDate(context),
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _handleSaveChanges, // Nút này chỉ lưu Text
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.6,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AvatarEditSection extends StatelessWidget {
  final VoidCallback? onCameraTap;
  final String? avatarUrl;
  final bool isUploading;

  const _AvatarEditSection({
    super.key,
    this.onCameraTap,
    this.avatarUrl,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Phần Ảnh Avatar
        Container(
          width: 110,
          height: 110, // [Đồng bộ] Kích thước 110 (cũ là 120)
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE2E8F0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: isUploading
                // [Đồng bộ] Padding 35 khi loading (cũ là 40)
                ? const Padding(
                    padding: EdgeInsets.all(35.0),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : (avatarUrl != null && avatarUrl!.isNotEmpty)
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    width: 110,
                    height: 110, // [Đồng bộ] Kích thước 110
                    errorBuilder: (ctx, err, stack) => Icon(
                      PhosphorIcons.user(PhosphorIconsStyle.fill),
                      size: 60,
                      color: Colors.grey,
                    ),
                  )
                // [SỬA 2]
                : Icon(
                    PhosphorIcons.user(PhosphorIconsStyle.fill),
                    size: 60,
                    color: Colors.grey,
                  ),
          ),
        ),

        // 2. Phần Nút Camera
        Positioned(
          bottom: 0,
          right: 0,
          // [Đồng bộ] Sử dụng cấu trúc Material > InkWell > Container như trang Profile
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
                // [Đồng bộ] Sử dụng PhosphorIcons và bỏ viền trắng
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
    );
  }
}
