import 'package:flutter/material.dart';
import 'dart:async';

// Import Core
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/custom_snackbar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // --- 1. Biến trạng thái hiệu ứng ---
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  // 🔴 THÊM BIẾN LOADING 🔴
  bool _isLoading = false;

  // --- 2. Controller ---
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // KỊCH BẢN HIỆU ỨNG
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
    _emailController.dispose();
    super.dispose();
  }

  // --- 3. HÀM LOGIC ---
  void _showMessage(String message, Color color) {
    // Xác định xem có phải lỗi không dựa vào màu sắc (Logic tạm thời)
    bool isError = color == Colors.red || color == Colors.orange;

    CustomSnackBar.show(
      context,
      title: isError ? "Error" : "Success",
      message: message,
      isError: isError,
    );
  }

  // --- GIAO DIỆN CHÍNH (SPLIT VIEW) ---
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
                              Icons.lock_reset_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Forgot Password?',
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
                              "Don't worry! It happens. Please enter the email address associated with your account.",
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

  // --- TÁCH RIÊNG NỘI DUNG FORM ---
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
                        'Forgot Password',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 28,
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

          const SizedBox(height: 40),

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
                  _buildLabel('Email'),
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'example@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Please enter your correct email to recover your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.56),
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // BUTTON (ĐÃ NÂNG CẤP LOADING)
          AnimatedSlide(
            offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _isButtonVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  // Khóa nút nếu đang loading
                  onPressed: _isLoading
                      ? null
                      : () async {
                          // 1. Ẩn bàn phím
                          FocusScope.of(context).unfocus();

                          String email = _emailController.text.trim();
                          if (email.isEmpty) {
                            _showMessage(
                              "Please enter your email!",
                              Colors.orange,
                            );
                            return;
                          }

                          // 2. Bắt đầu Loading
                          setState(() => _isLoading = true);

                          try {
                            final apiClient = ApiClient();
                            final response = await apiClient.post(
                              '/auth/forgot-password',
                              data: {"email": email},
                            );

                            if (response.statusCode == 200) {
                              _showMessage(
                                "OTP sent successfully!",
                                Colors.green,
                              );

                              // Chuyển trang
                              if (mounted) {
                                Navigator.pushNamed(
                                  context,
                                  '/otp_verification',
                                  arguments: email,
                                );
                              }
                            }
                          } catch (e) {
                            // Xử lý thông báo lỗi gọn gàng
                            String msg = e.toString();
                            if (msg.contains("Exception:")) {
                              msg = msg.replaceAll("Exception:", "").trim();
                            }
                            _showMessage(msg, Colors.red);
                          } finally {
                            // 3. Kết thúc Loading (Dù thành công hay thất bại)
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Inter',
                          ),
                        ),
                ),
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
}
