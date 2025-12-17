import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import các file core
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
// 1. IMPORT API CLIENT VÀ CUSTOM SNACKBAR
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

  // 2. THÊM BIẾN TRẠNG THÁI LOADING
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

  // 3. CẬP NHẬT HÀM XỬ LÝ GỌI API
  Future<void> _handleChangePassword() async {
    // Ẩn bàn phím để giao diện thoáng
    FocusScope.of(context).unfocus();

    String current = _currentPassController.text.trim();
    String newPass = _newPassController.text.trim();
    String confirm = _confirmPassController.text.trim();

    // --- Validation Client-side ---
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

    // Kiểm tra sơ bộ ở client (Backend cũng sẽ check lại)
    if (current == newPass) {
      CustomSnackBar.show(
        context,
        title: 'Error',
        message: "New password must be different from current password",
        isError: true,
      );
      return;
    }

    // --- Gọi API ---
    setState(() => _isLoading = true); // Bắt đầu loading

    try {
      final apiClient = ApiClient();

      // Endpoint này đã được định nghĩa trong Backend AuthController
      // Dữ liệu gửi đi khớp với ChangePasswordRequest DTO
      await apiClient.post(
        '/auth/change-password',
        data: {"currentPassword": current, "newPassword": newPass},
      );

      if (!mounted) return;

      // Thành công
      CustomSnackBar.show(
        context,
        title: 'Success',
        message: "Password changed successfully! Please login again if needed.",
      );

      // Đợi một chút rồi đóng màn hình
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      // Lỗi từ Server (VD: Sai mật khẩu cũ, Trùng lịch sử 3 lần gần nhất...)
      // ApiClient đã xử lý message, ta chỉ việc hiện lên
      if (!mounted) return;
      // Loại bỏ chữ "Exception: " nếu có để thông báo đẹp hơn
      String errorMsg = e.toString().replaceAll("Exception: ", "");
      CustomSnackBar.show(
        context,
        title: 'Failed',
        message: errorMsg,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Kết thúc loading
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ... (Phần AppBar giữ nguyên) ...
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'PASSWORD MANAGEMENT',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            // Thêm AbsorbPointer để chặn thao tác khi đang loading
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),

                        // 1. Current Password
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

                        // Forgot Password Link (Giữ nguyên)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              /* Navigate logic */
                            },
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

                        // 2. New Password
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
                          // Thêm onChanged để cập nhật realtime bảng rules
                          // (Lưu ý: CustomTextField của bạn cần hỗ trợ onChanged,
                          // nếu chưa có thì dùng ValueListenableBuilder như cũ là ổn)
                        ),

                        // Bảng Rule (Giữ nguyên logic cũ)
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

                        // 3. Confirm Password
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

                        // 4. Button Change Password
                        // Hiển thị Loading hoặc Nút bấm
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

  // ... (Giữ nguyên các hàm _buildLabel, _buildPasswordRules, _buildRuleItem) ...
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
    // ... Logic cũ giữ nguyên ...
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
