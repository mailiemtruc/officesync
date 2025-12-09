import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // (Giữ nguyên phần khai báo biến và initState của bạn)
  bool _isLogoVisible = false;
  bool _isTextVisible = false;
  bool _isButtonVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isLogoVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isTextVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Lấy chiều rộng màn hình hiện tại
    final width = MediaQuery.of(context).size.width;
    // Quy ước: Lớn hơn 800px thì coi là Desktop/Tablet ngang
    final isDesktop = width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isDesktop
            // --- GIAO DIỆN DESKTOP (Split View) ---
            ? Row(
                children: [
                  // CỘT TRÁI: Logo + Text (Chiếm 50% màn hình)
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: AppColors.primary.withOpacity(
                        0.05,
                      ), // Nền nhẹ cho sang
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 20),
                          _buildText(),
                        ],
                      ),
                    ),
                  ),
                  // CỘT PHẢI: Buttons (Chiếm 50% màn hình)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildButtons(),
                      ),
                    ),
                  ),
                ],
              )
            // --- GIAO DIỆN MOBILE (Như cũ) ---
            : SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    _buildLogo(),
                    const SizedBox(height: 20),
                    _buildText(),
                    const Spacer(flex: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _buildButtons(),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
      ),
    );
  }

  // --- TÁCH CÁC WIDGET RA ĐỂ TÁI SỬ DỤNG ---

  Widget _buildLogo() {
    return AnimatedScale(
      scale: _isLogoVisible ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      child: AnimatedOpacity(
        opacity: _isLogoVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: SizedBox(
          width: 279,
          height: 291,
          child: Image.asset('assets/images/logo2.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildText() {
    return AnimatedSlide(
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
                color: AppColors.primary,
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
                color: AppColors.primary,
                fontSize: 18,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return AnimatedSlide(
      offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _isButtonVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Quan trọng để căn giữa bên Desktop
          children: [
            CustomButton(
              text: 'Log In',
              onPressed: () => Navigator.pushNamed(context, '/login'),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Create Company',
              backgroundColor: const Color(0xFFCAD6FF),
              textColor: AppColors.primary,
              onPressed: () => Navigator.pushNamed(context, '/signup'),
            ),
          ],
        ),
      ),
    );
  }
}
