import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const AuthHeader({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
              onPressed: onBack,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 28, // Điều chỉnh size cho phù hợp
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
