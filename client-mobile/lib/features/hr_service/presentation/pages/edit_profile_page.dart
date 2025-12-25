import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart'; // Giả định bạn có widget này
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

  Future<void> _uploadAndAutoSaveAvatar(File file) async {
    setState(() => _isUploadingAvatar = true);
    try {
      // 1. Upload ảnh lên Storage Service (Port 8090)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:8090/api/files/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        String newAvatarUrl = data['url'];
        print("--> Upload Storage success: $newAvatarUrl");

        // 2. Cập nhật UI ngay lập tức
        setState(() {
          _currentAvatarUrl = newAvatarUrl;
        });

        // 3. [QUAN TRỌNG] TỰ ĐỘNG GỌI HR SERVICE ĐỂ LƯU AVATAR MỚI
        // Lưu ý: Ta dùng thông tin GỐC (widget.user) cho các trường text
        // để tránh lưu nhầm những gì người dùng đang gõ dở dang.

        String dbDob = widget.user.dateOfBirth;
        // Logic parse ngày sinh cũ để gửi đi cho đúng định dạng
        // (Nếu Repository của bạn tự xử lý thì tốt, nếu không thì parse lại cho chắc)

        await _repository.updateEmployee(
          widget.user.id ?? "",
          widget.user.fullName, // Giữ nguyên tên cũ trong DB
          widget.user.phone, // Giữ nguyên sđt cũ trong DB
          widget.user.dateOfBirth, // Giữ nguyên ngày sinh cũ
          avatarUrl: newAvatarUrl, // CHỈ CẬP NHẬT CÁI NÀY
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile picture updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Upload failed: ${response.body}");
      }
    } catch (e) {
      print("Auto-save avatar error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to update avatar: $e"),
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

      // Gọi update với thông tin Text mới + Avatar hiện tại
      final success = await _repository.updateEmployee(
        widget.user.id ?? "",
        _fullNameController.text.trim(), // Lấy tên MỚI từ ô nhập
        _phoneController.text.trim(), // Lấy sđt MỚI từ ô nhập
        dbDob, // Lấy ngày sinh MỚI
        avatarUrl:
            _currentAvatarUrl, // Avatar giữ nguyên (đã update ở bước trên rồi)
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
      // [XÓA] Bỏ AppBar
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              // [SỬA 1] Padding top = 0
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
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
                        onPressed: () => Navigator.of(context).pop(),
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
                    errorBuilder: (ctx, err, stack) =>
                        const Icon(Icons.person, size: 60, color: Colors.grey),
                  )
                : const Icon(Icons.person, size: 60, color: Colors.grey),
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
