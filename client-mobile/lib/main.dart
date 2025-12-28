import 'package:flutter/material.dart';

import 'features/core_service/presentation/pages/splash_screen.dart';
import 'features/core_service/presentation/pages/register_screen.dart';
import 'features/core_service/presentation/pages/login_screen.dart';
import 'features/core_service/presentation/pages/sign_up_screen.dart';
import 'features/core_service/presentation/pages/set_password_screen.dart';
import 'features/core_service/presentation/pages/forgot_password_screen.dart';
import 'features/core_service/presentation/pages/otp_verification_screen.dart';
import 'dashboard_screen.dart';
import 'features/hr_service/presentation/pages/user_profile_page.dart';

// --- THÊM IMPORT CÁC TRANG MỚI ---
import 'features/hr_service/presentation/pages/my_requests_page.dart';
import 'features/hr_service/presentation/pages/manager_request_list_page.dart';
import 'features/hr_service/presentation/pages/employee_list_page.dart';

import 'features/note_service/presentation/pages/note_list_screen.dart';

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
        fontFamily: 'Inter',
      ),

      home: const SplashScreen(),

      routes: {
        // Auth Routes
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/otp_verification': (context) => const OtpVerificationScreen(),
        '/set_password': (context) => const SetPasswordScreen(),

        // Main Routes
        '/dashboard': (context) => const DashboardScreen(
          userInfo: {
            'fullName': 'Test User',
            'role': 'STAFF',
          }, // Default test data
        ),
        '/user_profile': (context) => const UserProfilePage(),

        // --- CÁC ROUTE CHỨC NĂNG MỚI (MENU) ---
        '/my_requests': (context) => const MyRequestsPage(),
        // '/manager_requests': (context) => const ManagerRequestListPage(),
        '/employees': (context) => const EmployeeListPage(),
        '/notes': (context) => const NoteListScreen(),
      },
    );
  }
}
