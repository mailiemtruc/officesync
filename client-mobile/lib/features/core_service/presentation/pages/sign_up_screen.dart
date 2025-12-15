import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng FilteringTextInputFormatter
import 'dart:async';

// Import Core
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/api/api_client.dart'; // 1. Import API Client
import '../../../../core/utils/custom_snackbar.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  // Biến loading để khóa nút khi đang gửi mã
  bool _isLoading = false;

  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

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
    _companyController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  // --- 1. GỬI MÃ XÁC THỰC EMAIL ---
  Future<void> _handleVerifyEmail() async {
    // Validate form
    if (_companyController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _dobController.text.isEmpty) {
      _showMessage("Please fill all required fields", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/auth/send-register-otp',
        data: {
          "email": _emailController.text.trim(),
          "mobile": _phoneController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        // Gửi thành công -> Hiện Dialog nhập mã
        if (mounted) _showOtpDialog();
      }
    } catch (e) {
      String msg = e.toString().replaceAll("Exception:", "").trim();
      _showMessage(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. DIALOG NHẬP OTP ---
  void _showOtpDialog() {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Verify Email",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "We sent a code to ${_emailController.text}.\nEnter it below to verify ownership.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 5,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "----",
                counterText: "",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              String otp = otpController.text.trim();

              // 1. Validate độ dài
              if (otp.length != 4) {
                _showMessage("Please enter full 4-digit code", Colors.orange);
                return;
              }

              // 2. Gọi API để kiểm tra tính đúng sai với Server
              try {
                final apiClient = ApiClient();
                final response = await apiClient.post(
                  '/auth/verify-register-otp', // Gọi API kiểm tra
                  data: {"email": _emailController.text.trim(), "otp": otp},
                );

                // 3. Nếu Server xác nhận đúng (Status 200)
                if (response.statusCode == 200) {
                  if (context.mounted) {
                    Navigator.pop(context); // Đóng Dialog
                    _navigateToSetPassword(otp); // Chuyển trang
                  }
                }
              } catch (e) {
                // 4. Nếu sai (Server trả lỗi 400) -> Hiện thông báo lỗi
                String msg = e.toString();
                if (msg.contains("Exception:")) {
                  msg = msg.replaceAll("Exception:", "").trim();
                }

                // Hiển thị lỗi ngay lập tức
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg), // Ví dụ: "Invalid verification code!"
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 3. CHUYỂN TRANG ---
  void _navigateToSetPassword(String otp) {
    final signUpData = {
      "companyName": _companyController.text.trim(),
      "fullName": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "mobile": _phoneController.text.trim(),
      "dob": _dobController.text.trim(),
      "otp": otp, // 🔴 Kèm mã OTP để Server verify lúc tạo user
    };

    Navigator.pushNamed(context, '/set_password', arguments: signUpData);
  }

  void _showMessage(String msg, Color color) {
    bool isError = color == Colors.red || color == Colors.orange;

    CustomSnackBar.show(
      context,
      title: isError ? "Action Failed" : "Success",
      message: msg,
      isError: isError,
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
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.business_center_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Join OfficeSync',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Start your digital transformation journey today.',
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
                        constraints: const BoxConstraints(maxWidth: 550),
                        child: _buildFormContent(context),
                      ),
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: _buildFormContent(context),
                ),
              ),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
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
                        'Create Company',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 30,
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

          // FORM FIELDS
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
                  _buildLabel("Company name"),
                  CustomTextField(
                    controller: _companyController,
                    hintText: "OfficeSync VN",
                  ),
                  _buildLabel("Full name"),
                  CustomTextField(
                    controller: _nameController,
                    hintText: "Enter your name",
                  ),
                  _buildLabel("Email"),
                  CustomTextField(
                    controller: _emailController,
                    hintText: "example@example.com",
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildLabel("Mobile Number"),
                  CustomTextField(
                    controller: _phoneController,
                    hintText: "**********",
                    keyboardType: TextInputType.phone,
                  ),
                  _buildLabel("Date Of Birth"),
                  CustomTextField(
                    controller: _dobController,
                    hintText: "DD/MM/YYYY",
                    readOnly: true,
                    onTap: _selectDate,
                    suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // BUTTON & FOOTER
          AnimatedSlide(
            offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _isButtonVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'By continuing, you agree to \n',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          TextSpan(
                            text: 'Terms of Use',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: ' and ',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          TextSpan(
                            text: 'Privacy Policy.',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // NÚT CONTINUE (Đã sửa logic)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _handleVerifyEmail, // Gọi hàm gửi OTP
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(
                          0.6,
                        ),
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
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'already have an account? ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18, // Giảm font size một chút cho cân đối
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
