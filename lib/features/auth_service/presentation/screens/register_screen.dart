import 'package:flutter/material.dart';
import 'dart:async';
// Import Core
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Biến trạng thái hiệu ứng
  bool _isLogoVisible = false;
  bool _isTextVisible = false;
  bool _isButtonVisible = false;

  @override
  void initState() {
    super.initState();
    // 1. Hiện Logo
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isLogoVisible = true);
    });

    // 2. Hiện Text
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isTextVisible = true);
    });

    // 3. Hiện Nút
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // --- PHẦN 1: LOGO (Zoom + Fade) ---
              AnimatedScale(
                scale: _isLogoVisible ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _isLogoVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: SizedBox(
                    width: 279,
                    height: 291,
                    child: Image.asset(
                      'assets/images/logo2.png', // Đảm bảo ảnh này có trong folder assets
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- PHẦN 2: TEXT (Slide Up) ---
              AnimatedSlide(
                offset: _isTextVisible ? Offset.zero : const Offset(0, 0.5),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutQuart,
                child: AnimatedOpacity(
                  opacity: _isTextVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: const [
                      Text(
                        'OfficeSync',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primary, // Dùng màu từ Core
                          fontSize: 55,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'The Pulse of Business',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.primary, // Dùng màu từ Core
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // --- PHẦN 3: BUTTONS (Slide Up) ---
              AnimatedSlide(
                offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isButtonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                    ), // Căn lề nút gọn gàng
                    child: Column(
                      children: [
                        // NÚT LOG IN
                        CustomButton(
                          text: 'Log In',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login'),
                          // CustomButton mặc định màu xanh, chữ trắng -> Đúng ý Log In
                        ),

                        const SizedBox(height: 20),

                        // NÚT CREATE COMPANY (Màu nền nhạt, chữ xanh)
                        CustomButton(
                          text: 'Create Company',
                          backgroundColor: const Color(
                            0xFFCAD6FF,
                          ), // Màu nền nhạt riêng của nút này
                          textColor: AppColors.primary, // Chữ xanh
                          onPressed: () =>
                              Navigator.pushNamed(context, '/signup'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
