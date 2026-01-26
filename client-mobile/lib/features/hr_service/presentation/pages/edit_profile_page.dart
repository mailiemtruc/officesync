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
import '../../domain/repositories/employee_repository.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/utils/user_update_event.dart';

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
  late String _initialFullName;
  late String _initialPhone;
  late String _initialDob;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _currentAvatarUrl;
  File? _localAvatarFile;
  bool _hasUpdates = false;
  late final EmployeeRepository _repository;
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

    // Logic parse ngày sinh
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

    // Lưu lại giá trị ban đầu sau khi đã format xong
    _initialFullName = widget.user.fullName;
    _initialPhone = widget.user.phone;
    _initialDob = dobDisplay;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        final file = File(image.path);

        // [MỚI] Hiển thị ảnh ngay lập tức (Optimistic UI)
        setState(() {
          _localAvatarFile = file;
          _isUploadingAvatar = true;
        });

        // Tiến hành upload ngầm
        _uploadAndAutoSaveAvatar(file);
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _uploadAndAutoSaveAvatar(File file) async {
    // _isUploadingAvatar đã được set = true ở _pickImage rồi
    try {
      // 1. Upload ảnh lên Server chứa ảnh (MinIO/S3...)
      String newAvatarUrl = await _repository.uploadFile(file);
      print("--> Upload Repository success: $newAvatarUrl");

      // 2. Gọi API cập nhật thông tin nhân viên (Backend)
      // CHỜ cập nhật xong mới đổi UI để đảm bảo đồng bộ
      final success = await _repository.updateEmployee(
        widget.user.id ?? "",
        widget.user.id ?? "",
        widget.user.fullName,
        widget.user.phone,
        widget.user.dateOfBirth,
        avatarUrl: newAvatarUrl,
      );

      // 3. Nếu thành công -> Cập nhật UI
      if (success && mounted) {
        setState(() {
          _currentAvatarUrl = newAvatarUrl;
          _localAvatarFile = null; // Xóa ảnh local để hiển thị ảnh mạng
          _hasUpdates = true; // Đánh dấu để reload khi back về
          _isUploadingAvatar = false; // Tắt loading
        });
        UserUpdateEvent().notify();
        CustomSnackBar.show(
          context,
          title: 'Success',
          message: 'Profile picture updated successfully!',
          isError: false,
        );
      }
    } catch (e) {
      print("Auto-save avatar error: $e");
      // Nếu lỗi -> Hủy ảnh local, quay về ảnh cũ
      if (mounted) {
        setState(() {
          _localAvatarFile = null;
          _isUploadingAvatar = false;
        });

        String msg = e.toString().replaceAll("Exception: ", "");
        CustomSnackBar.show(
          context,
          title: 'Upload Failed',
          message: 'Failed to update avatar: $msg',
          isError: true,
        );
      }
    }
  }

  // --- LOGIC 2: BẤM NÚT SAVE MỚI LƯU TEXT ---

  Future<void> _handleSaveChanges() async {
    // [CHECK THAY ĐỔI] Kiểm tra xem có gì khác so với ban đầu không
    final currentName = _fullNameController.text.trim();
    final currentPhone = _phoneController.text.trim();
    final currentDob = _dobController.text.trim();

    // Lưu ý: Avatar được xử lý riêng (upload ngay khi chọn), nên ở đây chỉ check text
    final bool hasChanges =
        (currentName != _initialFullName) ||
        (currentPhone != _initialPhone) ||
        (currentDob != _initialDob);

    if (!hasChanges) {
      CustomSnackBar.show(
        context,
        title: 'No Changes',
        message: 'No changes detected to save.',
        isError: false, // Màu xanh hoặc xám báo info
        backgroundColor: const Color(0xFF6B7280),
      );
      return; // Dừng lại, không gọi API
    }

    // Nếu có thay đổi -> Tiếp tục gọi API như cũ
    setState(() => _isLoading = true);

    try {
      String dbDob = "";
      if (_dobController.text.isNotEmpty) {
        try {
          DateTime parsed = DateFormat('dd/MM/yyyy').parse(_dobController.text);
          dbDob = DateFormat('yyyy-MM-dd').format(parsed);
        } catch (_) {}
      }

      final success = await _repository.updateEmployee(
        widget.user.id ?? "",
        widget.user.id ?? "",
        _fullNameController.text.trim(),
        _phoneController.text.trim(),
        dbDob,
        avatarUrl: _currentAvatarUrl,
      );

      if (success && mounted) {
        UserUpdateEvent().notify();
        CustomSnackBar.show(
          context,
          title: 'Success',
          message: 'Profile details updated successfully!',
          isError: false,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        CustomSnackBar.show(
          context,
          title: 'Error',
          message: msg,
          isError: true,
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

  // Đồng bộ màu sắc DatePicker
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
      // Builder chỉnh màu
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary, // Màu header & nút chọn
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary, // Màu nút Cancel/OK
              ),
            ),
          ),
          child: child!,
        );
      },
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

                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                          color: AppColors.primary,
                          size: 24,
                        ),
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

                  _AvatarEditSection(
                    avatarUrl: _currentAvatarUrl,
                    localImage: _localAvatarFile,
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
  final File? localImage; // [THÊM]
  final bool isUploading;

  const _AvatarEditSection({
    super.key,
    this.onCameraTap,
    this.avatarUrl,
    this.localImage,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    // [ĐỒNG BỘ MÀU SẮC] Giống trang User Profile
    final placeholderBgColor = Colors.grey[200];
    final placeholderIconColor = Colors.grey[400];

    return Stack(
      children: [
        // 1. Phần Ảnh Avatar
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: placeholderBgColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: localImage != null
                ? Image.file(
                    localImage!,
                    fit: BoxFit.cover,
                    width: 110,
                    height: 110,
                    // [FIX] Thêm errorBuilder để bắt lỗi khi file chưa load được
                    errorBuilder: (context, error, stackTrace) {
                      // Nếu lỗi load file local, thử hiển thị ảnh mạng cũ, nếu không có thì hiện Icon
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

        // 2. Phần Nút Camera
        Positioned(
          bottom: 0,
          right: 0,
          child: Material(
            // Đổi màu xám khi đang loading
            color: isUploading ? Colors.grey : AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: isUploading ? null : onCameraTap,
              child: Container(
                padding: const EdgeInsets.all(7),
                width: 32,
                height: 32,
                // Hiển thị loading nhỏ ngay tại nút camera
                child: isUploading
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
    );
  }
}
