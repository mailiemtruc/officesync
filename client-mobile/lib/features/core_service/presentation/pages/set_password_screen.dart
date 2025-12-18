import 'package:flutter/material.dart';
import 'dart:async';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/custom_snackbar.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  bool _isLoading = false;

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(
        () {},
      ); // Rebuild UI mỗi khi nhập password để cập nhật các dòng check
    });
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

  Future<void> _handleRegister(Map<String, dynamic> prevData) async {
    setState(() => _isLoading = true);

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
          _showSuccessDialog(
            "Your account has been created.\nPlease log in to continue.",
          );
        }
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("Exception:")) {
        msg = msg.replaceAll("Exception:", "").trim();
      }
      if (mounted) _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/auth/reset-password',
        data: {"email": email, "password": newPassword, "otp": otp},
      );

      if (response.statusCode == 200) {
        if (mounted) {
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    CustomSnackBar.show(
      context,
      title: "Error",
      message: message,
      isError: true,
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
                      child: const Center(
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
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

  Widget _buildRuleItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: isValid ? Colors.green : Colors.grey.withOpacity(0.5),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isValid ? Colors.black87 : Colors.grey,
                fontSize: 13,
                fontFamily: 'Inter',
                // Gạch ngang chữ nếu chưa thỏa mãn (tuỳ chọn, ở đây tôi để bình thường cho dễ đọc)
                fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRules(String password) {
    bool hasMinLength = password.length >= 8;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    // Lưu ý: Regex này bao gồm _ - + = như file gốc của bạn để khớp với mô tả
    bool hasSpecialChar = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>_+\-=]'),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF), // Màu nền giống code cũ của bạn
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ), // Thêm viền nhẹ cho đẹp
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRuleItem("Minimum 8 characters", hasMinLength),
          _buildRuleItem("At least 1 uppercase letter (A-Z)", hasUppercase),
          _buildRuleItem("At least 1 lowercase letter (a-z)", hasLowercase),
          _buildRuleItem("At least 1 number (0-9)", hasDigit),
          _buildRuleItem(
            "At least 1 special character (@, #, _, - ...)",
            hasSpecialChar,
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: AnimatedOpacity(
                    opacity: _isTitleVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: const Text(
                      'Set Password',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          AnimatedOpacity(
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

                // --- THAY THẾ ĐOẠN CŨ BẰNG ĐOẠN NÀY ---
                _buildPasswordRules(_passwordController.text),

                // --------------------------------------
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

          const SizedBox(height: 40),

          AnimatedOpacity(
            opacity: _isButtonVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),

                onPressed: _isLoading
                    ? null
                    : () {
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
                          _showError(
                            "Invalid password:\n- ${errors.join("\n- ")}",
                          );
                          return;
                        }

                        final args =
                            ModalRoute.of(context)!.settings.arguments
                                as Map<String, dynamic>?;

                        if (args != null) {
                          if (args.containsKey('isReset') &&
                              args['isReset'] == true) {
                            final email = args['email'];
                            final otp = args['otp'];
                            if (otp == null) {
                              _showError("Security Error: OTP is missing!");
                              return;
                            }
                            _handleResetPassword(email, otp, pass);
                          } else {
                            _handleRegister(args);
                          }
                        } else {
                          _showError("Error: Missing data! Please go back.");
                        }
                      },

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
                        'Confirm',
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

  void _showSuccessDialog(String message) {
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
                  Navigator.pop(context);
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
