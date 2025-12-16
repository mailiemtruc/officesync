import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLogoVisible = false;
  bool _isTextVisible = false;
  bool _isButtonVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isLogoVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isTextVisible = true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isButtonVisible = true);
    });
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
                    flex: 1,
                    child: Container(
                      color: AppColors.primary.withOpacity(0.05),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogo(isDesktop: true),
                          const SizedBox(height: 20),
                          _buildText(isDesktop: true),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: _buildButtons(),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    _buildLogo(isDesktop: false),
                    const SizedBox(height: 20),
                    _buildText(isDesktop: false),
                    const Spacer(flex: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _buildButtons(),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLogo({required bool isDesktop}) {
    final double size = isDesktop ? 400 : 279;

    return AnimatedScale(
      scale: _isLogoVisible ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      child: AnimatedOpacity(
        opacity: _isLogoVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset('assets/images/logo2.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildText({required bool isDesktop}) {
    final double titleSize = isDesktop ? 90 : 55;
    final double sloganSize = isDesktop ? 30 : 18;

    return AnimatedSlide(
      offset: _isTextVisible ? Offset.zero : const Offset(0, 0.5),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
      child: AnimatedOpacity(
        opacity: _isTextVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: Column(
          children: [
            Text(
              'OfficeSync',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: titleSize,
                fontStyle: FontStyle.italic,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The Pulse of Business',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: sloganSize,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return AnimatedSlide(
      offset: _isButtonVisible ? Offset.zero : const Offset(0, 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _isButtonVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomButton(
              text: 'Log In',
              onPressed: () => Navigator.pushNamed(context, '/login'),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Create Company',
              backgroundColor: const Color(0xFFCAD6FF),
              textColor: AppColors.primary,
              onPressed: () => Navigator.pushNamed(context, '/signup'),
            ),
          ],
        ),
      ),
    );
  }
}
