import 'package:flutter/material.dart';
import 'dart:async';
// Import file màu sắc dùng chung
import '../../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // 1. Biến trạng thái để kiểm soát hiệu ứng
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    // 2. Kích hoạt hiệu ứng ngay sau khi màn hình hiện lên (delay 100ms)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isVisible = true;
        });
      }
    });

    // 3. Đếm ngược 3 giây để chuyển trang
    // Trong thực tế, đây là chỗ kiểm tra Token để quyết định vào Home hay Login
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        // Chuyển sang màn hình Chào (RegisterScreen - nơi có nút Log In / Create Company)
        Navigator.pushReplacementNamed(context, '/register');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // SỬA: Dùng màu từ Core thay vì Hardcode
          color: AppColors.primary,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- PHẦN 1: LOGO CÓ HIỆU ỨNG ---
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutExpo,
              // Hiệu ứng trồi lên
              top: _isVisible ? 247 : 300,
              left: 67, // Bạn có thể cần căn chỉnh lại số này nếu đổi thiết bị
              child: AnimatedOpacity(
                duration: const Duration(seconds: 2),
                opacity: _isVisible ? 1.0 : 0.0,
                child: SizedBox(
                  width: 279,
                  height: 291,
                  child: Image.asset(
                    'assets/images/logo1.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // --- PHẦN 2: TÊN APP ---
            AnimatedPositioned(
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutExpo,
              top: _isVisible ? 584 : 650,
              left: 0, // Căn left 0 right 0 để text căn giữa chuẩn hơn
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 2),
                opacity: _isVisible ? 1.0 : 0.0,
                child: const Text(
                  'OfficeSync',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // SỬA: Dùng màu trắng chuẩn
                    color: Colors.white,
                    fontSize: 60,
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),

            // --- PHẦN 3: SLOGAN ---
            Positioned(
              left: 0,
              right: 0,
              top: 650,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 3),
                opacity: _isVisible ? 1.0 : 0.0,
                child: const Text(
                  'The Pulse of Business',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
