// import 'package:flutter/material.dart';

// // 1. IMPORT QUAN TRỌNG: Import màn hình Profile bạn vừa làm

// import 'features/hr_service/presentation/pages/manager_request_list_page.dart';

// void main() {
//   runApp(const OfficeSyncHRTestApp());
// }

// class OfficeSyncHRTestApp extends StatelessWidget {
//   const OfficeSyncHRTestApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'OfficeSync HR Test', // Đổi tên để biết đang chạy bản test
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: const Color(0xFF2260FF), // Màu xanh chủ đạo của AppColors
//           brightness: Brightness.light,
//         ),
//         useMaterial3: true,
//         fontFamily: 'Inter', // Font chữ mặc định
//       ),

//       // 2. CẤU HÌNH ĐỂ CHẠY THẲNG VÀO MÀN HÌNH CỦA BẠN
//       // Thay vì Splash hay Login, ta gọi thẳng UserProfilePage() làm màn hình chính
//       home: const ManagerRequestListPage(),
//     );
//   }
// }
