import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// [QUAN TRỌNG] Import file main để lấy rootScaffoldMessengerKey
// Hãy kiểm tra đường dẫn này có đúng với project của bạn không
import '../../main.dart';

class CustomSnackBar {
  // 1. Hàm hiển thị khi CÓ Context (Dùng trong các màn hình UI)
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = false,
    double? marginBottom,
    Color? backgroundColor,
  }) {
    // Gọi hàm tạo giao diện chung
    final snackBar = _buildSnackBar(
      title: title,
      message: message,
      isError: isError,
      marginBottom: marginBottom,
      backgroundColor: backgroundColor,
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // 2. [MỚI] Hàm hiển thị TOÀN CỤC (Dùng cho Service chạy ngầm như SecurityService)
  static void showGlobal({
    required String title,
    required String message,
    bool isError = false,
    double? marginBottom,
    Color? backgroundColor,
  }) {
    // Gọi hàm tạo giao diện chung
    final snackBar = _buildSnackBar(
      title: title,
      message: message,
      isError: isError,
      marginBottom: marginBottom,
      backgroundColor: backgroundColor,
    );

    // Dùng GlobalKey để hiển thị đè lên mọi màn hình
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    rootScaffoldMessengerKey.currentState?.showSnackBar(snackBar);
  }

  // 3. Hàm Private để xây dựng giao diện SnackBar (Tránh lặp code)
  static SnackBar _buildSnackBar({
    required String title,
    required String message,
    required bool isError,
    double? marginBottom,
    Color? backgroundColor,
  }) {
    int autoDuration = 3000 + (message.length * 50);
    if (autoDuration > 6000) autoDuration = 6000;

    return SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20, // Hiển thị phía trên nếu muốn, hoặc để mặc định
        bottom: marginBottom ?? 20,
      ),
      duration: Duration(milliseconds: autoDuration),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Logic màu sắc
          color:
              backgroundColor ??
              (isError ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              isError
                  ? PhosphorIconsBold.warningCircle
                  : PhosphorIconsBold.checkCircle,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                      fontFamily: 'Inter',
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
