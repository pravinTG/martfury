import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/session_manager.dart';
import 'main_tabs_screen.dart';
import 'phone_login_screen.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/splash';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Wait for splash screen display
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    // Check if session is valid
    final isValid = await SessionManager.isSessionValid();
    
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      isValid ? MainTabsScreen.routeName : PhoneLoginScreen.routeName,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: const _SplashLogo()),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentGeometry.center, // a bit lower than exact center
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Goodies',
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: 'World',
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

