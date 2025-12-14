import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// Import Core
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/api/api_client.dart';

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
  int _start = 60;
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

  // --- HÀM LOGIC ---
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

  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        if (mounted) {
          setState(() {
            timer.cancel();
            _canResend = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _start--;
          });
        }
      }
    });
  }

  // 🔴 SỬA HÀM RESEND CODE (ĐÃ NÂNG CẤP GIAO DIỆN) 🔴
  Future<void> _resendCode() async {
    if (_canResend) {
      final emailArg = ModalRoute.of(context)?.settings.arguments;
      if (emailArg == null) {
        _showMessage("Error: Email not found!", Colors.red);
        return;
      }
      final String email = emailArg as String;

      try {
        _showMessage("Resending code...", AppColors.primary);

        final apiClient = ApiClient();
        final response = await apiClient.post(
          '/auth/forgot-password',
          data: {"email": email},
        );

        if (response.statusCode == 200) {
          setState(() {
            // 🔴 SỬA VỊ TRÍ 2: Đổi 30 thành 60
            _start = 60;

            _canResend = false;
          });
          _startTimer();
          _showMessage("Code resent successfully! Check Email.", Colors.green);
        }
      } catch (e) {
        _showMessage("Failed to resend: ${e.toString()}", Colors.red);
      }
    }
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
                              Icons.mark_email_read_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Verify Identity',
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
                              'Enter the 4-digit code sent to your device to verify your identity.',
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

  // --- TÁCH RIÊNG NỘI DUNG FORM OTP ---
  Widget _buildFormContent() {
    String timerText = "00:${_start.toString().padLeft(2, '0')}";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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

          // CONTENT
          AnimatedSlide(
            offset: _isContentVisible ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _isContentVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: Column(
                children: [
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
                    // Gọi hàm _resendCode mới
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

          // BUTTON
          AnimatedSlide(
            offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _isButtonVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 800),
              child: CustomButton(
                text: 'Continue',
                onPressed: () async {
                  FocusScope.of(context).unfocus(); // Ẩn bàn phím
                  String otp = _controllers
                      .map((c) => c.text)
                      .join(); // Lấy chuỗi OTP

                  // 1. Validate độ dài
                  if (otp.length < 4) {
                    _showMessage(
                      "Please enter complete OTP code!",
                      Colors.orange,
                    );
                    return;
                  }

                  final email =
                      ModalRoute.of(context)!.settings.arguments as String;

                  try {
                    // 2. Gọi API Verify (Chỉ để check xem đúng không trước khi cho qua)
                    final apiClient = ApiClient();
                    final response = await apiClient.post(
                      '/auth/verify-otp',
                      data: {"email": email, "otp": otp},
                    );

                    if (response.statusCode == 200) {
                      _showMessage("Verified!", Colors.green);

                      // 3. 🔴 QUAN TRỌNG: Phải truyền OTP sang màn hình tiếp theo
                      Navigator.pushNamed(
                        context,
                        '/set_password',
                        arguments: {
                          'email': email,
                          'otp': otp, // <--- THÊM DÒNG NÀY
                          'isReset':
                              true, // Cờ đánh dấu đây là luồng quên mật khẩu
                        },
                      );
                    }
                  } catch (e) {
                    // Xử lý lỗi từ Backend (Ví dụ: Mã sai, hết hạn)
                    String msg = e.toString();
                    // Lọc bớt chữ "Exception:" nếu có để thông báo đẹp hơn
                    if (msg.contains("Exception:")) {
                      msg = msg.replaceAll("Exception:", "").trim();
                    }
                    // Nếu là lỗi Dio (API) thì parse message từ response
                    // (Tùy vào cách bạn viết class ApiClient, nhưng logic cơ bản là vậy)

                    _showMessage(msg, Colors.red);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      decoration: ShapeDecoration(
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
          color: AppColors.primary,
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
