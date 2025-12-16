import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // Import để xử lý JSON
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 1. Dùng thư viện bảo mật
import '../../../../core/config/app_colors.dart';
import '../../../../dashboard_screen.dart';

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
    // Hiệu ứng hiện logo
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });

    // Gọi hàm kiểm tra đăng nhập bảo mật
    _checkLoginStatus();
  }

  // --- HÀM KIỂM TRA TRẠNG THÁI ĐĂNG NHẬP (BẢO MẬT) ---
  Future<void> _checkLoginStatus() async {
    // 1. Đợi 3 giây để người dùng kịp nhìn thấy Logo
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 2. 🔴 SỬA ĐỔI: Đọc từ Secure Storage thay vì SharedPreferences 🔴
    const storage = FlutterSecureStorage();

    // Đọc Token và User Info đã lưu lúc Login
    final String? token = await storage.read(key: 'auth_token');
    final String? userInfoStr = await storage.read(key: 'user_info');

    // 3. Kiểm tra logic: Phải có cả Token và User Info mới hợp lệ
    if (token != null && userInfoStr != null) {
      // --- TRƯỜNG HỢP A: ĐÃ ĐĂNG NHẬP (CÓ TOKEN) ---
      try {
        // Giải mã chuỗi JSON thành Map
        final Map<String, dynamic> userData = jsonDecode(userInfoStr);

        // Chuyển thẳng vào Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userInfo: userData),
          ),
        );
      } catch (e) {
        // Nếu dữ liệu lỗi, bắt đăng nhập lại
        Navigator.pushReplacementNamed(context, '/register');
      }
    } else {
      // --- TRƯỜNG HỢP B: CHƯA ĐĂNG NHẬP ---
      Navigator.pushReplacementNamed(context, '/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Phần giao diện giữ nguyên như cũ) ...
    // 1. Lấy kích thước màn hình
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    // 2. Tính toán kích thước Responsive
    final double logoWidth = isDesktop ? 400 : 279;
    final double logoHeight = isDesktop ? 417 : 291;
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
                  // --- LOGO ---
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

                  // --- TÊN APP ---
                  Text(
                    'OfficeSync',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- SLOGAN ---
                  Text(
                    'The Pulse of Business',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: sloganFontSize,
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
