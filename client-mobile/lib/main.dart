import 'package:flutter/material.dart';

// 1. Import các màn hình
import 'features/core_service/presentation/pages/splash_screen.dart';
import 'features/core_service/presentation/pages/register_screen.dart';
import 'features/core_service/presentation/pages/login_screen.dart';
import 'features/core_service/presentation/pages/sign_up_screen.dart';
import 'features/core_service/presentation/pages/set_password_screen.dart';
import 'features/core_service/presentation/pages/forgot_password_screen.dart';
import 'features/core_service/presentation/pages/otp_verification_screen.dart';

void main() {
  runApp(const OfficeSyncApp());
}

class OfficeSyncApp extends StatelessWidget {
  const OfficeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OfficeSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2260FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Khai báo font mặc định cho toàn app (nếu muốn)
      ),

      // 2. Thiết lập màn hình chạy đầu tiên
      // Nếu bạn muốn test ngay màn hình Đăng ký, hãy sửa dòng dưới thành: home: const RegisterScreen(),
      home: const SplashScreen(),

      // 3. Khai báo các tuyến đường (Routes) để điều hướng sau này
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/otp_verification': (context) => const OtpVerificationScreen(),
        '/set_password': (context) => const SetPasswordScreen(),
        // Sau này thêm login thì: '/login': (context) => const LoginScreen(),
      },
    );
  }
}
