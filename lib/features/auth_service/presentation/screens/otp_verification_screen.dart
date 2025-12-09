import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// Import Core
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  // --- 1. Biến trạng thái hiệu ứng ---
  bool _isTitleVisible = false;
  bool _isContentVisible = false;
  bool _isButtonVisible = false;

  // --- 2. Quản lý 4 ô nhập OTP ---
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  // --- 3. Quản lý đồng hồ đếm ngược ---
  Timer? _timer;
  int _start = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Kịch bản hiệu ứng
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isTitleVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isContentVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // --- HÀM THÔNG BÁO ---
  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Hàm đếm ngược
  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          _canResend = true;
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  // Hàm gửi lại mã
  void _resendCode() {
    if (_canResend) {
      setState(() {
        _start = 30;
        _canResend = false;
      });
      _startTimer();
      _showMessage("Code resent successfully!", Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    String timerText = "00:${_start.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- HEADER (Stack: Back + Title) ---
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
                            'Verification',
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

              const SizedBox(height: 50),

              // --- CONTENT ---
              AnimatedSlide(
                offset: _isContentVisible ? Offset.zero : const Offset(0, 0.2),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _isContentVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Column(
                    children: [
                      // 4 Ô OTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 60,
                            height: 60,
                            child: _buildOtpBox(index),
                          );
                        }),
                      ),

                      const SizedBox(height: 30),

                      // TIMER & RESEND TEXT
                      if (!_canResend)
                        Text(
                          'Resend code in $timerText',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w300,
                          ),
                        ),

                      TextButton(
                        onPressed: _canResend ? _resendCode : null,
                        child: Text(
                          'Resend Code',
                          style: TextStyle(
                            color: _canResend ? AppColors.primary : Colors.grey,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // DESCRIPTION
                      Text(
                        'Please enter the correct code we sent you to complete the verification.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.56),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // --- BUTTON (Dùng CustomButton) ---
              AnimatedSlide(
                offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _isButtonVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: CustomButton(
                    text: 'Continue',
                    onPressed: () {
                      FocusScope.of(context).unfocus(); // Ẩn bàn phím

                      String otp = _controllers.map((c) => c.text).join();

                      if (otp.length < 4) {
                        _showMessage("Please enter 4 digits!", Colors.red);
                      } else {
                        // Thành công -> Chuyển trang tạo mật khẩu
                        Navigator.pushNamed(context, '/set_password');
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET OTP BOX ---
  Widget _buildOtpBox(int index) {
    return Container(
      decoration: ShapeDecoration(
        // Dùng màu nền inputFill từ AppColors cho đồng bộ
        color: AppColors.inputFill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Colors.transparent),
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.primary, // Chữ màu xanh chủ đạo
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 3) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else {
              FocusScope.of(context).unfocus();
            }
          } else {
            if (index > 0) {
              FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
            }
          }
        },
      ),
    );
  }
}
