import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/api/api_client.dart';
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
  bool _isLoading = false;

  final _companyController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();

  // [SỬA 1] Khai báo FocusNode cố định cho email
  final _emailFocusNode = FocusNode();

  static const List<String> _emailDomains = [
    '@gmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@icloud.com',
    '@hotmail.com',
    '@fpt.com.vn',
  ];

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
    // [SỬA 2] Hủy FocusNode để tránh rò rỉ bộ nhớ
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) {
    final RegExp phoneRegex = RegExp(r'(0[3|5|7|8|9])+([0-9]{8})\b');
    return phoneRegex.hasMatch(phone);
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
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

  Future<void> _handleVerifyEmail() async {
    if (_companyController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _dobController.text.isEmpty) {
      _showMessage("Please fill all required fields", Colors.orange);
      return;
    }

    String email = _emailController.text.trim();

    final emailRegex = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );

    if (!emailRegex.hasMatch(email)) {
      _showMessage(
        "Invalid email format! Please remove special characters like #, \$, %",
        Colors.orange,
      );
      return;
    }

    if (!_isValidPhone(_phoneController.text.trim())) {
      _showMessage("Invalid phone number format (VN)", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/auth/send-register-otp',
        data: {"email": email, "mobile": _phoneController.text.trim()},
      );

      if (response.statusCode == 200) {
        if (mounted) _showOtpDialog();
      }
    } catch (e) {
      String msg = e.toString().replaceAll("Exception:", "").trim();
      _showMessage(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              if (otp.length != 4) {
                if (context.mounted) {
                  CustomSnackBar.show(
                    context,
                    title: "Error",
                    message: "Please enter full 4-digit code",
                    isError: true,
                  );
                }
                return;
              }

              try {
                final apiClient = ApiClient();
                final response = await apiClient.post(
                  '/auth/verify-register-otp',
                  data: {"email": _emailController.text.trim(), "otp": otp},
                );

                if (response.statusCode == 200) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    _navigateToSetPassword(otp);
                  }
                }
              } catch (e) {
                String msg = e.toString().replaceAll("Exception:", "").trim();

                if (context.mounted) {
                  CustomSnackBar.show(
                    context,
                    title: "Verification Failed",
                    message: msg,
                    isError: true,
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

  void _navigateToSetPassword(String otp) {
    final signUpData = {
      "companyName": _companyController.text.trim(),
      "fullName": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "mobile": _phoneController.text.trim(),
      "dob": _dobController.text.trim(),
      "otp": otp,
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

  Widget _buildEmailField() {
    return RawAutocomplete<String>(
      textEditingController: _emailController,

      // [SỬA 3] Sử dụng biến FocusNode đã khai báo
      focusNode: _emailFocusNode,

      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }

        if (textEditingValue.text.contains('@')) {
          final split = textEditingValue.text.split('@');
          final prefix = split[0];
          final domainPart = split.length > 1 ? split[1] : '';

          return _emailDomains
              .where(
                (option) =>
                    option.contains('@$domainPart') && option != '@$domainPart',
              )
              .map((option) => '$prefix$option');
        }

        return _emailDomains.map((option) => '${textEditingValue.text}$option');
      },

      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return CustomTextField(
              controller: textEditingController,
              focusNode: focusNode,
              hintText: "example@gmail.com",
              keyboardType: TextInputType.emailAddress,
            );
          },

      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 300,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
                          Icons.business,
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
          SizedBox(
            height: 50,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
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
                      'Create Company',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 30,
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

                _buildEmailField(),

                _buildLabel("Mobile Number"),
                CustomTextField(
                  controller: _phoneController,
                  hintText: "09xxxxxxxxx",
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
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

          const SizedBox(height: 40),

          AnimatedOpacity(
            opacity: _isButtonVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleVerifyEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continue',
                        style: TextStyle(fontSize: 18, color: Colors.white),
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
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
