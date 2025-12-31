import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../dashboard_screen.dart';
import '../../../../../core/services/websocket_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isVisible = true);
    });

    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    const storage = FlutterSecureStorage();

    final String? token = await storage.read(key: 'auth_token');
    final String? userInfoStr = await storage.read(key: 'user_info');

    if (token != null && userInfoStr != null) {
      try {
        final Map<String, dynamic> userData = jsonDecode(userInfoStr);
        WebSocketService().connect();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userInfo: userData),
          ),
        );
      } catch (e) {
        Navigator.pushReplacementNamed(context, '/register');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    final double logoWidth = isDesktop ? 400 : 279;
    final double logoHeight = isDesktop ? 417 : 291;
    final double titleFontSize = isDesktop ? 90 : 60;
    final double sloganFontSize = isDesktop ? 30 : 20;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: AppColors.primary),
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(seconds: 2),
            opacity: _isVisible ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutExpo,
              transform: Matrix4.translationValues(0, _isVisible ? 0 : 50, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: logoWidth,
                    height: logoHeight,
                    child: Image.asset(
                      'assets/images/logo1.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'OfficeSync',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
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
                      color: Colors.white,
                      fontSize: sloganFontSize,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.10,
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
}
