import 'package:flutter/material.dart';
import 'dart:async';

// Import Core
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // --- 1. Biến trạng thái hiệu ứng ---
  bool _isTitleVisible = false;
  bool _isFormVisible = false;
  bool _isButtonVisible = false;

  // --- 2. Controller ---
  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Hiệu ứng xuất hiện
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

  // Hàm chọn ngày sinh
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
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER (Dùng Stack chuẩn: Back trái - Title giữa) ---
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
                            'Create Company', // Tiêu đề đúng Figma của bạn
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

              // --- FORM FIELDS ---
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
                      // 1. Company Name
                      _buildLabel("Company name"),
                      CustomTextField(
                        controller: _companyController,
                        hintText: "OfficeSync VN",
                      ),

                      // 2. Full name
                      _buildLabel("Full name"),
                      CustomTextField(
                        controller: _nameController,
                        hintText: "Enter your name",
                      ),

                      // 3. Email
                      _buildLabel("Email"),
                      CustomTextField(
                        controller: _emailController,
                        hintText: "example@example.com",
                        keyboardType: TextInputType.emailAddress,
                      ),

                      // 4. Mobile Number
                      _buildLabel("Mobile Number"),
                      CustomTextField(
                        controller: _phoneController,
                        hintText: "**********",
                        keyboardType: TextInputType.phone,
                      ),

                      // 5. Date Of Birth (Chọn lịch)
                      _buildLabel("Date Of Birth"),
                      CustomTextField(
                        controller: _dobController,
                        hintText: "DD / MM / YYYY",
                        readOnly: true, // Không cho gõ tay
                        onTap: _selectDate, // Bấm vào hiện lịch
                        // Nếu muốn thêm icon lịch thì uncomment dòng dưới (cần update CustomTextField để hỗ trợ suffixIcon nếu chưa có)
                        // suffixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- BUTTON & FOOTER ---
              AnimatedSlide(
                offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isButtonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      // Điều khoản sử dụng
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

                      // NÚT CONTINUE (Dùng CustomButton)
                      CustomButton(
                        text: 'Continue',
                        onPressed: () {
                          // Chuyển sang màn hình tạo mật khẩu
                          Navigator.pushNamed(context, '/set_password');
                        },
                      ),

                      const SizedBox(height: 20),

                      // Footer Login Link
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
        ),
      ),
    );
  }

  // Widget hiển thị Label (Tiêu đề nhỏ trên ô input)
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20, // Font size label theo thiết kế
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
