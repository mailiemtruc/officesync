import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import Config & Widgets
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // Controller
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // Biến trạng thái ẩn/hiện mật khẩu
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // --- HÀM KIỂM TRA ĐỘ MẠNH MẬT KHẨU (Trả về true nếu OK) ---
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

  // --- HÀM HIỂN THỊ THÔNG BÁO (SnackBar) ---
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
        ),
        backgroundColor: isError
            ? Colors.red
            : Colors.green, // Đỏ nếu lỗi, Xanh nếu đúng
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  // --- HÀM XỬ LÝ KHI BẤM NÚT CHANGE PASSWORD ---
  void _handleChangePassword() {
    String current = _currentPassController.text.trim();
    String newPass = _newPassController.text.trim();
    String confirm = _confirmPassController.text.trim();

    // 1. Kiểm tra rỗng
    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showMessage("Please fill in all fields", isError: true);
      return;
    }

    // 2. Kiểm tra quy tắc mật khẩu mới
    if (!_checkPasswordComplexity(newPass)) {
      _showMessage("New password does not meet requirements", isError: true);
      return;
    }

    // 3. Kiểm tra xác nhận mật khẩu
    if (newPass != confirm) {
      _showMessage("Confirm password does not match", isError: true);
      return;
    }

    // 4. Kiểm tra trùng mật khẩu cũ (Optional)
    if (current == newPass) {
      _showMessage(
        "New password must be different from current password",
        isError: true,
      );
      return;
    }

    // 5. TODO: Gọi API đổi mật khẩu ở đây
    // Giả lập thành công
    _showMessage("Password changed successfully!", isError: false);

    // Đợi 1 giây rồi quay lại màn hình trước
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                      onPressed: () {
                        setState(() => _obscureCurrent = !_obscureCurrent);
                      },
                    ),
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Navigate to Forgot Password
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontStyle: FontStyle.italic,
                          decoration: TextDecoration.underline,
                          // --- SỬA LỖI: Thêm màu gạch chân ---
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
                      onPressed: () {
                        setState(() => _obscureNew = !_obscureNew);
                      },
                    ),
                    // Lắng nghe thay đổi để update bảng rule bên dưới
                    onTap: () => setState(() {}),
                    // Dùng onChanged để khi gõ phím cũng update luôn
                  ),
                  // Cần rebuild khi gõ để update các dấu tích xanh
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
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),

                  const SizedBox(height: 60),

                  // 4. Button Change Password
                  CustomButton(
                    text: 'Change Password',
                    onPressed: _handleChangePassword, // Gọi hàm xử lý logic
                  ),

                  const SizedBox(height: 20),
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

  // Widget hiển thị danh sách quy tắc mật khẩu
  Widget _buildPasswordRules(String password) {
    bool hasMinLength = password.length >= 8;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE), // Nền xanh nhạt
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
            color: isValid ? Colors.green : Colors.grey, // Xanh lá nếu đúng
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Inter',
                color: isValid ? Colors.black : const Color(0xFF6A6A6A),
                decoration: isValid ? TextDecoration.none : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
