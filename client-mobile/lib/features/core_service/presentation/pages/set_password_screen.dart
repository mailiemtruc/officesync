import 'package:flutter/material.dart';
import 'dart:async';

// Import Core
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/api/api_client.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isTitleVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isFormVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- 1. XỬ LÝ ĐĂNG KÝ (CREATE COMPANY) ---
  Future<void> _handleRegister(Map<String, dynamic> prevData) async {
    final String password = _passwordController.text;

    final requestBody = {
      "companyName": prevData['companyName'],
      "fullName": prevData['fullName'],
      "email": prevData['email'],
      "mobileNumber": prevData['mobile'],
      "dateOfBirth": prevData['dob'],
      "password": password,
      "otp": prevData['otp'],
    };
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/auth/register',
        data: requestBody,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          // ✅ Truyền thông báo cụ thể cho trường hợp Đăng ký thành công
          _showSuccessDialog(
            "Your account has been created.\nPlease log in to continue.",
          );
        }
      }
    } catch (e) {
      String msg = e.toString();
      // Loại bỏ chữ Exception: nếu có để thông báo thân thiện hơn
      if (msg.contains("Exception:")) {
        msg = msg.replaceAll("Exception:", "").trim();
      }
      if (mounted) _showError(msg);
    }
  }

  // --- 2. XỬ LÝ ĐẶT LẠI MẬT KHẨU (FORGOT PASSWORD) ---
  Future<void> _handleResetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/auth/reset-password',
        data: {"email": email, "password": newPassword, "otp": otp},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          // --- ĐOẠN ĐÃ SỬA ---
          // Gọi Dialog đẹp thay vì SnackBar
          _showSuccessDialog(
            "Password reset successfully!\nPlease log in with your new password.",
          );
        }
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("Exception:"))
        msg = msg.replaceAll("Exception:", "").trim();
      if (mounted) _showError(msg);
    }
  }

  // --- VALIDATION ---
  List<String> _validatePasswordErrors(String password) {
    List<String> errors = [];
    if (password.length < 8) errors.add("Minimum 8 characters");
    if (!password.contains(RegExp(r'[A-Z]')))
      errors.add("Missing uppercase letter");
    if (!password.contains(RegExp(r'[a-z]')))
      errors.add("Missing lowercase letter");
    if (!password.contains(RegExp(r'[0-9]'))) errors.add("Missing number");
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_+\-=]'))) {
      errors.add("Missing special character (@, #, _, - ...)");
    }
    return errors;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      color: AppColors.primary,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Secure Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Create a strong password to protect your business data and privacy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontFamily: 'Inter',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: _buildFormContent(),
                      ),
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildFormContent(),
                ),
              ),
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          SizedBox(
            height: 50,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: AnimatedSlide(
                    offset: _isTitleVisible
                        ? Offset.zero
                        : const Offset(0, -0.5),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: _isTitleVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: const Text(
                        'Set Password',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 26,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // FORM
          AnimatedSlide(
            offset: _isFormVisible ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _isFormVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Password"),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: "*************",
                    isPassword: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.primary,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '• Minimum 8 characters\n'
                      '• At least 1 uppercase letter (A-Z)\n'
                      '• At least 1 lowercase letter (a-z)\n'
                      '• At least 1 number (0-9)\n'
                      '• At least 1 special character (@, #, _, - ...)',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLabel("Confirm Password"),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: "*************",
                    isPassword: !_isConfirmPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.primary,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmPasswordVisible =
                            !_isConfirmPasswordVisible,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // BUTTON
          AnimatedSlide(
            offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _isButtonVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: CustomButton(
                text: 'Confirm', // Đổi tên nút thành Confirm cho chung
                onPressed: () {
                  String pass = _passwordController.text;
                  String confirm = _confirmPasswordController.text;

                  if (pass.isEmpty || confirm.isEmpty) {
                    _showError("Please enter complete information!");
                    return;
                  }
                  if (pass != confirm) {
                    _showError("Confirmation password does not match!");
                    return;
                  }
                  List<String> errors = _validatePasswordErrors(pass);
                  if (errors.isNotEmpty) {
                    String errorMsg =
                        "Invalid password:\n- ${errors.join("\n- ")}";
                    _showError(errorMsg);
                    return;
                  }

                  // 🔴 LOGIC ĐIỀU HƯỚNG QUAN TRỌNG 🔴
                  final args =
                      ModalRoute.of(context)!.settings.arguments
                          as Map<String, dynamic>?;

                  if (args != null) {
                    // TRƯỜNG HỢP 1: QUÊN MẬT KHẨU (Có cờ isReset)
                    if (args.containsKey('isReset') &&
                        args['isReset'] == true) {
                      // 🔴 SỬA: Lấy OTP và truyền vào hàm
                      final email = args['email'];
                      final otp = args['otp']; // Lấy OTP từ màn hình trước

                      if (otp == null) {
                        _showError("Security Error: OTP is missing!");
                        return;
                      }

                      _handleResetPassword(email, otp, pass);
                    }
                    // TRƯỜNG HỢP 2: ĐĂNG KÝ MỚI (Mặc định)
                    else {
                      _handleRegister(args);
                    }
                  } else {
                    _showError("Error: Missing data! Please go back.");
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }

  // Thay thế hàm _showSuccessDialog cũ bằng hàm này
  void _showSuccessDialog(String message) {
    // Thêm tham số message
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: AppColors.primary, size: 60),
              SizedBox(height: 10),
              Text(
                "Success!",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Sử dụng message được truyền vào
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  "Log in",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                onPressed: () {
                  Navigator.pop(context); // Đóng Dialog
                  // Chuyển thẳng về trang Login, xóa hết lịch sử cũ
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
