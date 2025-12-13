import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import Config & Widgets
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Controller
  final _fullNameController = TextEditingController(text: "Nguyen Van A");
  final _emailController = TextEditingController(text: "nguyenvana@gmail.com");
  final _phoneController = TextEditingController(text: "0909123456");
  final _dobController = TextEditingController(text: "01/10/1997");

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // --- HÀM HIỆN MENU CAMERA (BOTTOM SHEET) ---
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontFamily: 'Inter',
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
                  // 1. Avatar Section (Truyền hàm mở menu vào đây)
                  _AvatarEditSection(
                    onCameraTap: () => _showImagePickerOptions(context),
                  ),

                  const SizedBox(height: 40),

                  // 2. Form Input
                  _buildLabel('Full name'),
                  CustomTextField(
                    controller: _fullNameController,
                    hintText: 'Enter your full name',
                    keyboardType: TextInputType.name,
                  ),

                  const SizedBox(height: 30),

                  _buildLabel('Email'),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email address',
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
                    hintText: 'Enter phone number',
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
                    onTap: () {
                      _selectDate(context);
                    },
                  ),

                  // 3. Nút Save
                  const SizedBox(height: 60),

                  CustomButton(
                    text: 'Save changes',
                    onPressed: () {
                      // TODO: Gọi API Update
                      print("Updating Profile...");
                    },
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
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1997, 10, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }
}

// --- WIDGET AVATAR (Đã thêm Callback onCameraTap) ---
class _AvatarEditSection extends StatelessWidget {
  final VoidCallback? onCameraTap; // Callback

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

              // KHI BẤM NÚT -> GỌI CALLBACK
              onTap: onCameraTap,

              child: Container(
                padding: const EdgeInsets.all(8),
                width: 36,
                height: 36,
                child: Icon(
                  PhosphorIcons.camera(PhosphorIconsStyle.fill),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
