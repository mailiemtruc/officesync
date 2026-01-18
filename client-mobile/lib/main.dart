import 'dart:async'; // [MỚI] Để dùng runZonedGuarded
import 'package:flutter/material.dart';

// Import các trang
import 'features/core_service/presentation/pages/splash_screen.dart';
import 'features/core_service/presentation/pages/register_screen.dart';
import 'features/core_service/presentation/pages/login_screen.dart';
import 'features/core_service/presentation/pages/sign_up_screen.dart';
import 'features/core_service/presentation/pages/set_password_screen.dart';
import 'features/core_service/presentation/pages/forgot_password_screen.dart';
import 'features/core_service/presentation/pages/otp_verification_screen.dart';
import 'dashboard_screen.dart';
import 'features/hr_service/presentation/pages/user_profile_page.dart';
import 'features/attendance_service/presentation/pages/attendance_screen.dart';
import 'features/attendance_service/presentation/pages/manager_attendance_screen.dart';
import 'features/core_service/presentation/pages/director_company_profile_screen.dart';
import 'features/core_service/presentation/pages/all_companies_screen.dart';
import 'features/core_service/presentation/pages/create_admin_screen.dart';

// --- THÊM IMPORT CÁC TRANG MỚI ---
import 'features/hr_service/presentation/pages/my_requests_page.dart';
import 'features/hr_service/presentation/pages/manager_request_list_page.dart';
import 'features/hr_service/presentation/pages/employee_list_page.dart';
import 'features/note_service/presentation/pages/note_list_screen.dart';

// [MỚI] Import Analytics Screen (Hãy chắc chắn bạn đã tạo file này theo hướng dẫn trước)
// Nếu bạn để file này ở features/core_service/presentation/pages/analytics_screen.dart
// thì import đường dẫn tương ứng. Ví dụ:
import 'features/core_service/presentation/pages/analytics_screen.dart';

// ======================= FIREBASE SERVICES ==============================
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/notification_service/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // [MỚI] Analytics
import 'package:firebase_crashlytics/firebase_crashlytics.dart'; // [MỚI] Crashlytics
// ========================================================================

import 'features/task_service/presentation/pages/company_admin_page.dart';
import 'features/task_service/presentation/pages/manager_page.dart';
import 'features/task_service/presentation/pages/staff_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 👇 HÀM XỬ LÝ BACKGROUND MESSAGE
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print(
    "🌙 Nhận thông báo ngầm (Background/Terminated): ${message.notification?.title}",
  );
}

void main() async {
  // Sử dụng runZonedGuarded để bắt mọi lỗi tiềm ẩn (Crashlytics)
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Khởi tạo Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Cấu hình Crashlytics: Bắt lỗi Flutter Framework (Render, Widget...)
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      // 3. Đăng ký hàm xử lý thông báo ngầm
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      runApp(const OfficeSyncApp());
    },
    (error, stack) {
      // 4. Bắt các lỗi Async (Logic ngầm, Future, Stream...) gửi lên Crashlytics
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class OfficeSyncApp extends StatelessWidget {
  const OfficeSyncApp({super.key});

  // Tạo instance analytics & observer để theo dõi chuyển màn hình
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OfficeSync',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // [MỚI] Đăng ký Observer để Analytics tự động log màn hình
      navigatorObservers: <NavigatorObserver>[observer],

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
          userInfo: {'fullName': 'Test User', 'role': 'STAFF'},
        ),
        '/user_profile': (context) => const UserProfilePage(),

        // [MỚI] Route cho màn hình Analytics Dashboard
        '/analytics': (context) => const AnalyticsScreen(),

        // --- CÁC ROUTE CHỨC NĂNG ---
        '/my_requests': (context) => const MyRequestsPage(),
        '/manager_requests': (context) => const ManagerRequestListPage(),
        '/employees': (context) => const EmployeeListPage(),
        '/notes': (context) => const NoteListScreen(),

        '/attendance': (context) => const AttendanceScreen(),
        '/manager_attendance': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String role = args is String ? args : 'HR_MANAGER';
          return ManagerAttendanceScreen(userRole: role);
        },
        '/company_profile': (context) => const DirectorCompanyProfileScreen(),
        '/admin_companies': (context) => const AllCompaniesScreen(),
        '/create_admin': (context) => const CreateAdminScreen(),

        // Task Routes
        '/tasks': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String role = args is String ? args : 'STAFF';

          if (role == 'COMPANY_ADMIN') {
            return const CompanyAdminPage();
          } else if (role == 'MANAGER') {
            return const ManagerPage();
          } else {
            return const StaffPage();
          }
        },
      },
    );
  }
}
