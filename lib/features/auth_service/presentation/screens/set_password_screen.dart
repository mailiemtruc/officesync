import 'package:flutter/material.dart';
import 'dart:async';

// Import Core
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  // --- 1. Biến trạng thái hiệu ứng ---
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  // --- 2. Controller ---
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Hiệu ứng xuất hiện
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isTitleVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isFormVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- 3. LOGIC KIỂM TRA MẬT KHẨU ---
  List<String> _validatePasswordErrors(String password) {
    List<String> errors = [];
    if (password.length < 8) errors.add("Minimum 8 characters");
    if (!password.contains(RegExp(r'[A-Z]')))
      errors.add("Missing uppercase letter");
    if (!password.contains(RegExp(r'[a-z]')))
      errors.add("Missing lowercase letter");
    if (!password.contains(RegExp(r'[0-9]'))) errors.add("Missing number");
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_+\-=]'))) {
      errors.add("Missing special character (@, #, _, - ...)");
    }
    return errors;
  }

  // Hàm hiện thông báo
  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER (Stack: Back + Title) ---
              SizedBox(
                height: 50,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: AppColors.primary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: AnimatedSlide(
                        offset: _isTitleVisible
                            ? Offset.zero
                            : const Offset(0, -0.5),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        child: AnimatedOpacity(
                          opacity: _isTitleVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 800),
                          child: const Text(
                            'Set Password',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 26,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- FORM ---
              AnimatedSlide(
                offset: _isFormVisible ? Offset.zero : const Offset(0, 0.2),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _isFormVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Password
                      _buildLabel("Password"),
                      CustomTextField(
                        controller: _passwordController,
                        hintText: "*************",
                        isPassword: !_isPasswordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.primary,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                      ),

                      // 2. Rules Box
                      const SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF5F7FF,
                          ), // Màu nền nhạt riêng biệt cho box này
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '• Minimum 8 characters\n'
                          '• At least 1 uppercase letter (A-Z)\n'
                          '• At least 1 lowercase letter (a-z)\n'
                          '• At least 1 number (0-9)\n'
                          '• At least 1 special character (@, #, _, - ...)',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                            fontSize: 12,
                            fontFamily: 'Inter',
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Confirm Password
                      _buildLabel("Confirm Password"),
                      CustomTextField(
                        controller: _confirmPasswordController,
                        hintText: "*************",
                        isPassword: !_isConfirmPasswordVisible,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: AppColors.primary,
                          ),
                          onPressed: () => setState(
                            () => _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- BUTTON ---
              AnimatedSlide(
                offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isButtonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: CustomButton(
                    text: 'Create new password',
                    onPressed: () {
                      String pass = _passwordController.text;
                      String confirm = _confirmPasswordController.text;

                      if (pass.isEmpty || confirm.isEmpty) {
                        _showError("Please enter complete information!");
                        return;
                      }

                      if (pass != confirm) {
                        _showError("Confirmation password does not match!");
                        return;
                      }

                      List<String> errors = _validatePasswordErrors(pass);
                      if (errors.isNotEmpty) {
                        String errorMsg =
                            "Invalid password:\n- ${errors.join("\n- ")}";
                        _showError(errorMsg);
                        return;
                      }

                      _showSuccessDialog();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: AppColors.primary, size: 60),
              SizedBox(height: 10),
              Text(
                "Success!",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            "Your account has been created.\nPlease log in to continue.",
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  "Log in",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/register',
                    (route) => false,
                  );
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
