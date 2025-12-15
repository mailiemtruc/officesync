import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    bool isError = false,
  }) {
    // 1. Xóa thông báo cũ nếu đang hiện
    ScaffoldMessenger.of(context).clearSnackBars();

    // 2. Hiện thông báo mới
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent, // Nền trong suốt
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // Màu xanh lá (Success) hoặc Đỏ (Error)
            color: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
            children: [
              // Icon minh họa
              Icon(
                isError
                    ? PhosphorIconsBold.warningCircle
                    : PhosphorIconsBold.checkCircle,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              // Nội dung chữ
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
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
