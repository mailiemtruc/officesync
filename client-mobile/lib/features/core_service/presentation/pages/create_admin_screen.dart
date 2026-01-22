import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/api/api_client.dart';
import '../../widgets/skeleton_create_admin.dart';

class CreateAdminScreen extends StatefulWidget {
  const CreateAdminScreen({super.key});

  @override
  State<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<CreateAdminScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Biến loading khi submit form
  bool _isSubmitting = false;
  // Biến loading khi khởi tạo màn hình (để hiện skeleton)
  bool _isInitializing = true;

  final Color _primaryColor = const Color(0xFF2260FF);

  @override
  void initState() {
    super.initState();
    // Giả lập load dữ liệu ban đầu (để hiện Skeleton cho đẹp/đồng bộ)
    _simulateInitialLoad();
  }

  Future<void> _simulateInitialLoad() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _submit() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      CustomSnackBar.show(
        context,
        title: 'Missing Info',
        message: 'Please fill in all required fields.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final client = ApiClient();
      await client.post(
        '/admin/create-admin',
        data: {
          "fullName": _fullNameController.text.trim(),
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
          "mobileNumber": _phoneController.text.trim(),
        },
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          title: 'Success',
          message: 'Super Admin account created successfully!',
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: 'Error',
          message: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // [XÓA] Đoạn code return sớm cũ:
    // if (_isInitializing) { return const SkeletonCreateAdmin(); }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),

      // --- APPBAR (LUÔN HIỂN THỊ) ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2260FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "NEW SUPER ADMIN",
          style: TextStyle(
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.bold,
            fontSize: 24,
            fontFamily: 'Inter',
          ),
        ),
      ),

      // --- BODY (KIỂM TRA LOADING TẠI ĐÂY) ---
      body: _isInitializing
          ? const SkeletonCreateAdmin() // <--- NẾU ĐANG LOAD THÌ HIỆN SKELETON Ở BODY
          : SingleChildScrollView(
              // <--- NẾU XONG RỒI THÌ HIỆN FORM
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2260FF).withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              PhosphorIconsBold.userPlus,
                              size: 32,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            "Account Information",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.blueGrey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            "Create a new administrator for the system",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Fields
                        _buildModernLabel("Full Name"),
                        CustomTextField(
                          controller: _fullNameController,
                          hintText: "Ex: Nguyen Van A",
                          prefixIcon: Icon(
                            PhosphorIconsRegular.user,
                            color: _primaryColor,
                          ),
                          fillColor: const Color(0xFFF8FAFC),
                        ),

                        _buildModernLabel("Email Address"),
                        CustomTextField(
                          controller: _emailController,
                          hintText: "admin@system.com",
                          prefixIcon: Icon(
                            PhosphorIconsRegular.envelope,
                            color: _primaryColor,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          fillColor: const Color(0xFFF8FAFC),
                        ),

                        _buildModernLabel("Mobile Number"),
                        CustomTextField(
                          controller: _phoneController,
                          hintText: "090xxxxxxx",
                          prefixIcon: Icon(
                            PhosphorIconsRegular.phone,
                            color: _primaryColor,
                          ),
                          keyboardType: TextInputType.phone,
                          fillColor: const Color(0xFFF8FAFC),
                        ),

                        _buildModernLabel("Password"),
                        CustomTextField(
                          controller: _passwordController,
                          hintText: "••••••••",
                          isPassword: true,
                          prefixIcon: Icon(
                            PhosphorIconsRegular.lock,
                            color: _primaryColor,
                          ),
                          fillColor: const Color(0xFFF8FAFC),
                        ),

                        const SizedBox(height: 40),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: _primaryColor.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    "Create Account",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModernLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
