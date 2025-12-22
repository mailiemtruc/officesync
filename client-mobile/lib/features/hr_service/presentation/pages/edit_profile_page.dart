import 'dart:convert'; // [MỚI] Cần import cái này để xử lý JSON lỗi
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';

// Import Config & Widgets & Data
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
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
  late final EmployeeRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    _fullNameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phone);

    String dobDisplay = "";
    if (widget.user.dateOfBirth.isNotEmpty &&
        widget.user.dateOfBirth != 'N/A') {
      try {
        DateTime date = DateTime.parse(widget.user.dateOfBirth);
        dobDisplay = DateFormat('dd/MM/yyyy').format(date);
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

  // --- HÀM GỌI API UPDATE (ĐÃ SỬA LỖI HIỂN THỊ MESSAGE) ---
  Future<void> _handleUpdate() async {
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
        _fullNameController.text.trim(),
        _phoneController.text.trim(),
        dbDob,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        // [LOGIC MỚI] Xử lý chuỗi JSON xấu xí thành text đẹp
        String msg = e.toString().replaceAll("Exception: ", "");

        // Kiểm tra nếu lỗi có chứa JSON từ backend
        if (msg.contains("Failed to update:")) {
          // Lấy phần JSON phía sau dấu hai chấm
          String rawJson = msg.replaceAll("Failed to update:", "").trim();
          try {
            // Thử giải mã JSON
            final decoded = jsonDecode(rawJson);
            if (decoded is Map && decoded.containsKey('message')) {
              // Lấy đúng nội dung trong 'message'
              msg = decoded['message'];
            } else {
              // Nếu không đúng định dạng mong đợi thì lấy text thô đã cắt
              msg = rawJson;
            }
          } catch (_) {
            // Nếu không parse được JSON, dùng text thô
            msg = rawJson;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
            ), // Giờ sẽ hiện: "Phone number ... already exists!"
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(height: 100),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 30),
              child: Column(
                children: [
                  _AvatarEditSection(
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
                      onPressed: _isLoading ? null : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
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
  const _AvatarEditSection({this.onCameraTap});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE2E8F0),
            image: const DecorationImage(
              image: NetworkImage("https://placehold.co/190x178"),
              fit: BoxFit.cover,
            ),
          ),
          child: const Icon(Icons.person, size: 60, color: Colors.grey),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: onCameraTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
