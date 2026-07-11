import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../token_storage_service.dart';
import 'info_screen.dart';
import 'main_navigation_screen.dart';

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
    _timer = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      final isLoggedIn = await TokenStorageService.isLoggedIn();
      final savedUserId = await TokenStorageService.getUserId();

      if (user != null || (isLoggedIn && savedUserId != null && savedUserId.isNotEmpty)) {
        Navigator.of(context).pushReplacementNamed(MainNavigationScreen.routeName);
      } else {
        Navigator.of(context).pushReplacementNamed(InfoScreen.routeName);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.headerRed,
      body: const _SplashLogo(),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Image.asset(
              'assets/logo5.png',
            ),
          ),
          // const SizedBox(height: 16),
          // RichText(
          //   text: TextSpan(
          //     children: [
          //       TextSpan(
          //         text: 'Goodies',
          //         style: GoogleFonts.poppins(
          //           fontSize: 40,
          //           fontWeight: FontWeight.w600,
          //           color: Colors.white,
          //           fontStyle:FontStyle.italic
          //         ),
          //       ),
          //       TextSpan(
          //         text: 'World',
          //         style: GoogleFonts.poppins(
          //           fontSize: 40,
          //           fontWeight: FontWeight.w600,
          //           fontStyle:FontStyle.italic,
          //
          //           color: Colors.white,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

