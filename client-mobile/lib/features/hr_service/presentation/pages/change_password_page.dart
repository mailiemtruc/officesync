import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import các file core
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/custom_snackbar.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  bool _checkPasswordComplexity(String password) {
    bool hasMinLength = password.length >= 8;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasMinLength &&
        hasUppercase &&
        hasLowercase &&
        hasDigit &&
        hasSpecialChar;
  }

  Future<void> _handleChangePassword() async {
    FocusScope.of(context).unfocus();

    String current = _currentPassController.text.trim();
    String newPass = _newPassController.text.trim();
    String confirm = _confirmPassController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      CustomSnackBar.show(
        context,
        title: 'Error',
        message: "Please fill in all fields",
        isError: true,
      );
      return;
    }

    if (!_checkPasswordComplexity(newPass)) {
      CustomSnackBar.show(
        context,
        title: 'Weak Password',
        message: "New password does not meet requirements",
        isError: true,
      );
      return;
    }

    if (newPass != confirm) {
      CustomSnackBar.show(
        context,
        title: 'Mismatch',
        message: "Confirm password does not match",
        isError: true,
      );
      return;
    }

    if (current == newPass) {
      CustomSnackBar.show(
        context,
        title: 'Error',
        message: "New password must be different from current password",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      await apiClient.post(
        '/auth/change-password',
        data: {"currentPassword": current, "newPassword": newPass},
      );

      if (!mounted) return;

      CustomSnackBar.show(
        context,
        title: 'Success',
        message: "Password changed successfully! Please login again if needed.",
      );

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString().replaceAll("Exception: ", "");
      CustomSnackBar.show(
        context,
        title: 'Failed',
        message: errorMsg,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // [SỬA LỖI QUAN TRỌNG] Đổi Center -> Align(topCenter)
        // Center sẽ căn giữa dọc làm nội dung bị trôi xuống giữa màn hình
        // Align topCenter sẽ đẩy nội dung lên sát trên cùng -> Header sẽ đồng bộ
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Khoảng cách chuẩn 20px từ đỉnh an toàn
                        const SizedBox(height: 20),

                        // Header đồng bộ
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                PhosphorIcons.caretLeft(
                                  PhosphorIconsStyle.bold,
                                ),
                                color: AppColors.primary,
                                size: 24,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'PASSWORD MANAGEMENT',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 24,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 30),

                        _buildLabel('Current password'),
                        CustomTextField(
                          controller: _currentPassController,
                          hintText: 'Enter current password',
                          isPassword: _obscureCurrent,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? PhosphorIcons.eyeSlash()
                                  : PhosphorIcons.eye(),
                              color: Colors.black,
                            ),
                            onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontStyle: FontStyle.italic,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        _buildLabel('New password'),
                        CustomTextField(
                          controller: _newPassController,
                          hintText: 'Enter new password',
                          isPassword: _obscureNew,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? PhosphorIcons.eyeSlash()
                                  : PhosphorIcons.eye(),
                              color: Colors.black,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                          onTap: () => setState(() {}),
                        ),

                        ValueListenableBuilder(
                          valueListenable: _newPassController,
                          builder: (context, TextEditingValue value, __) {
                            return Column(
                              children: [
                                const SizedBox(height: 12),
                                _buildPasswordRules(value.text),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        _buildLabel('Confirm new password'),
                        CustomTextField(
                          controller: _confirmPassController,
                          hintText: 'Confirm new password',
                          isPassword: _obscureConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? PhosphorIcons.eyeSlash()
                                  : PhosphorIcons.eye(),
                              color: Colors.black,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),

                        const SizedBox(height: 60),

                        _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              )
                            : CustomButton(
                                text: 'Change Password',
                                onPressed: _handleChangePassword,
                              ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPasswordRules(String password) {
    bool hasMinLength = password.length >= 8;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildRuleItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Inter',
                color: isValid ? Colors.black : const Color(0xFF6A6A6A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
