import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // Hiệu ứng hiện ra
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });

    // Chuyển trang
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/register');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lấy kích thước màn hình
    final size = MediaQuery.of(context).size;
    // 2. Kiểm tra xem có phải màn hình lớn không (Tablet/Desktop)
    final isDesktop = size.width > 800;

    // 3. Tính toán kích thước Responsive
    // Nếu là Desktop: Logo to 400px. Nếu là Mobile: Logo 279px.
    final double logoWidth = isDesktop ? 400 : 279;
    final double logoHeight = isDesktop ? 417 : 291; // Giữ đúng tỷ lệ ảnh

    // Nếu là Desktop: Chữ to 90px. Nếu Mobile: Chữ 60px.
    final double titleFontSize = isDesktop ? 90 : 60;
    final double sloganFontSize = isDesktop ? 30 : 20;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: AppColors.primary),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(seconds: 2),
            opacity: _isVisible ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutExpo,
              transform: Matrix4.translationValues(0, _isVisible ? 0 : 50, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- PHẦN 1: LOGO (Responsive Size) ---
                  // Dùng AnimatedContainer ở đây để nếu resize cửa sổ, nó mượt mà hơn
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: logoWidth,
                    height: logoHeight,
                    child: Image.asset(
                      'assets/images/logo1.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- PHẦN 2: TÊN APP (Responsive Font) ---
                  Text(
                    'OfficeSync',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          titleFontSize, // Font size thay đổi theo màn hình
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- PHẦN 3: SLOGAN (Responsive Font) ---
                  Text(
                    'The Pulse of Business',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          sloganFontSize, // Font size thay đổi theo màn hình
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
