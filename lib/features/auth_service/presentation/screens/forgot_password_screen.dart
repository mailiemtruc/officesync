import 'package:flutter/material.dart';
import 'dart:async';

// Import Core
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // --- 1. Biến trạng thái hiệu ứng ---
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  // --- 2. Controller ---
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // --- KỊCH BẢN HIỆU ỨNG ---
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
    _emailController.dispose();
    super.dispose();
  }

  // --- 3. HÀM KIỂM TRA EMAIL (Regex chuẩn) ---
  bool _isValidEmail(String email) {
    return RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(email);
  }

  // --- 4. HÀM HIỆN THÔNG BÁO ---
  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
                          color: AppColors.primary, // Dùng màu chuẩn
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
                            'Forgot Password',
                            style: TextStyle(
                              color: AppColors.primary, // Dùng màu chuẩn
                              fontSize: 28,
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

              const SizedBox(height: 40),

              // --- FORM NHẬP EMAIL ---
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
                      // Label
                      _buildLabel('Email'),

                      // Dùng Widget chung CustomTextField
                      CustomTextField(
                        controller: _emailController,
                        hintText: 'example@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // Text hướng dẫn
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Please enter your correct email to recover your password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.56),
                            fontSize: 13,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- NÚT SEND CODE ---
              AnimatedSlide(
                offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isButtonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: CustomButton(
                    text: 'Send Code',
                    onPressed: () {
                      String email = _emailController.text.trim();

                      // 1. Kiểm tra rỗng
                      if (email.isEmpty) {
                        _showMessage("Please enter Email!", Colors.red);
                        return;
                      }

                      // 2. Kiểm tra định dạng Email
                      if (!_isValidEmail(email)) {
                        _showMessage(
                          "Invalid email! (Example: abc@gmail.com)",
                          Colors.red,
                        );
                        return;
                      }

                      // 3. Giả lập gửi thành công
                      print("Đang gửi mã đến: $email");
                      FocusScope.of(context).unfocus(); // Ẩn bàn phím

                      _showMessage("Verification code sent!", Colors.green);

                      // Chuyển sang màn hình nhập OTP
                      Navigator.pushNamed(context, '/otp_verification');
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

  // Widget hiển thị Label nhỏ
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
}
