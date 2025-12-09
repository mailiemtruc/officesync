import 'package:flutter/material.dart';
import 'dart:async';

// Import Core
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- 1. Biến trạng thái hiệu ứng ---
  bool _isHeaderVisible = false;
  bool _isInputVisible = false;
  bool _isButtonVisible = false;

  // --- 2. Controller ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Hiệu ứng xuất hiện
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isHeaderVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isInputVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- GIAO DIỆN CHÍNH (SPLIT VIEW) ---
  @override
  Widget build(BuildContext context) {
    // 1. Kiểm tra kích thước màn hình
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isDesktop
            // --- GIAO DIỆN DESKTOP (Giữ nguyên Split View) ---
            ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: AppColors.primary,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.waving_hand_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'To keep connected with us please login with your personal info.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontFamily: 'Inter',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: _buildLoginForm(),
                      ),
                    ),
                  ),
                ],
              )
            // --- GIAO DIỆN MOBILE (ĐÃ SỬA) ---
            : Align(
                // SỬA Ở ĐÂY: Thay Center bằng Align + topCenter
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildLoginForm(),
                ),
              ),
      ),
    );
  }

  // --- TÁCH RIÊNG NỘI DUNG FORM LOGIN ---
  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER (Back + Hello) ---
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
                    offset: _isHeaderVisible
                        ? Offset.zero
                        : const Offset(0, -0.5),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: _isHeaderVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: const Text(
                        'Hello!',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 30,
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

          // --- CHỮ "WELCOME" ---
          const SizedBox(height: 40),
          AnimatedSlide(
            offset: _isHeaderVisible ? Offset.zero : const Offset(0, -0.5),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _isHeaderVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: const Text(
                'Welcome',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 35,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // --- FORM NHẬP LIỆU ---
          AnimatedSlide(
            offset: _isInputVisible ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _isInputVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Email or Mobile Number'),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'example@example.com',
                  ),

                  const SizedBox(height: 25),

                  _buildLabel('Password'),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: '*************',
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

                  const SizedBox(height: 10),

                  // Nút Quên mật khẩu
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/forgot_password');
                      },
                      child: const Text(
                        'Forgot Password',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // --- NÚT LOG IN & FOOTER ---
          AnimatedSlide(
            offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _isButtonVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Column(
                children: [
                  CustomButton(
                    text: 'Log In',
                    onPressed: () {
                      // Logic Login
                      print("Login: ${_emailController.text}");
                      // Navigator.pushNamed(context, '/home');
                    },
                  ),

                  const SizedBox(height: 25),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don’t have an account? ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          fontFamily: 'Inter',
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/signup'),
                        child: const Text(
                          'Create Company',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Helper
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
