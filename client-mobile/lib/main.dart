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
import 'features/attendance_service/presentation/pages/attendance_screen.dart';
import 'features/attendance_service/presentation/pages/manager_attendance_screen.dart';
import 'features/core_service/presentation/pages/director_company_profile_screen.dart';

// --- THÊM IMPORT CÁC TRANG MỚI ---
import 'features/hr_service/presentation/pages/my_requests_page.dart';
import 'features/hr_service/presentation/pages/manager_request_list_page.dart';
import 'features/hr_service/presentation/pages/employee_list_page.dart';

import 'features/note_service/presentation/pages/note_list_screen.dart';

// ======================= TASK_SERVICE ==============================
import 'features/task_service/presentation/pages/task_list_page.dart';
import 'features/task_service/presentation/pages/staff_task_screen.dart';
import 'features/task_service/presentation/pages/management_task_screen.dart';
// ======================= TASK_SERVICE ==============================

// ======================= notification_SERVICE ==============================
import 'package:firebase_core/firebase_core.dart';
import 'features/notification_service/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ======================= notification_SERVICE ==============================

// 👇 1. THÊM HÀM NÀY Ở NGOÀI CÙNG (Trước hàm main)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Cần khởi tạo Firebase để xử lý ngầm
  await Firebase.initializeApp();
  print(
    "🌙 Nhận thông báo ngầm (Background/Terminated): ${message.notification?.title}",
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 👇 2. ĐĂNG KÝ HÀM BACKGROUND
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const OfficeSyncApp());
}

class OfficeSyncApp extends StatelessWidget {
  const OfficeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ======================= TASK_SERVICE ==============================
    //  'COMPANY_ADMIN', 'MANAGER', 'STAFF'
    const String currentTestRole = 'COMPANY_ADMIN';
    // ======================= TASK_SERVICE ==============================
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

      // ======================= TASK_SERVICE ==============================

      // home: const DashboardScreen(
      //   userInfo: {
      //     'id': 'admin_01',
      //     'fullName': 'CEO OfficeSync',
      //     'role': 'COMPANY_ADMIN', // <-- Quan trọng: Đổi thành COMPANY_ADMIN
      //     'avatarUrl': null,
      //   },
      // ),
      // home: Navigator(
      //   onGenerateRoute: (settings) {
      //     // Định nghĩa Role muốn test ở đây
      //     const String testRole =
      //         'STAFF'; // Đổi thành 'MANAGER', 'COMPANY_ADMIN', hoặc 'STAFF'

      //     return MaterialPageRoute(
      //       builder: (context) {
      //         if (testRole == 'STAFF') {
      //           return const StaffTaskScreen(); // Staff dùng màn hình riêng
      //         } else {
      //           return const ManagementTaskScreen(
      //             userRole: testRole,
      //           ); // Manager/Admin dùng chung màn hình này
      //         }
      //       },
      //       settings: const RouteSettings(arguments: testRole),
      //     );
      //   },
      // ),
      // home: Builder(
      //   builder: (context) {
      //     if (currentTestRole == 'STAFF') {
      //       return const StaffTaskScreen();
      //     } else {
      //       return const ManagementTaskScreen(userRole: currentTestRole);
      //     }
      //   },
      // ),
      // home: const DashboardScreen(
      //   userInfo: {
      //     'id': 'user_001',
      //     'fullName': 'Demo User ($currentTestRole)',
      //     'role': currentTestRole, // Truyền Role vào Dashboard
      //     'avatarUrl': null,
      //   },
      // ),

      // ======================= TASK_SERVICE ==============================
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
        '/manager_requests': (context) => const ManagerRequestListPage(),
        '/employees': (context) => const EmployeeListPage(),
        '/notes': (context) => const NoteListScreen(),

        '/attendance': (context) => const AttendanceScreen(),
        '/manager_attendance': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;

          // Sửa: Nếu không có args, mặc định lấy 'HR_MANAGER' để test cho dễ,
          // hoặc lấy role từ Storage nếu có thể (nhưng cách truyền args là chuẩn nhất)
          String role = args is String ? args : 'HR_MANAGER';

          return ManagerAttendanceScreen(userRole: role);
        },
        '/company_profile': (context) => const DirectorCompanyProfileScreen(),

        // ======================= TASK_SERVICE ==============================
        // Logic phân quyền: Route này nhận 'role' từ Dashboard gửi sang
        '/tasks': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          // Mặc định là STAFF nếu không có args (để tránh crash app)
          String role = args is String ? args : 'STAFF';

          // 1. Nếu là STAFF -> Vào màn hình riêng của nhân viên (My Job & Forms)
          if (role == 'STAFF') {
            return const StaffTaskScreen();
          }
          // 2. Nếu là MANAGER -> Vào Management Screen (có Tabs My Job/Assigned)
          else if (role == 'MANAGER') {
            return const ManagementTaskScreen(userRole: 'MANAGER');
          }
          // 3. Nếu là COMPANY_ADMIN -> Vào Management Screen (Full quyền, xem báo cáo tháng)
          else {
            return const ManagementTaskScreen(userRole: 'COMPANY_ADMIN');
          }
        },

        // ======================= TASK_SERVICE ==============================
      },
    );
  }
}
