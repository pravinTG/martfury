import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // ── Wait for Firebase to fully restore the auth session ──────────────────
    // On aggressive-battery phones (Realme, OPPO, Xiaomi etc.), the OS kills
    // the app process entirely. When the user reopens the app, Firebase Auth
    // needs time to restore the current user from its local cache.
    //
    // A fixed 700ms timer is NOT enough on these devices — FirebaseAuth
    // .currentUser is still null when the timer fires, so the app falls back
    // to the stale saved token → 401 "User not found" → cart fails.
    //
    // Fix: wait for the first authStateChanges() event (max 4 s) so we know
    // the exact auth state before navigating.
    User? firebaseUser;
    try {
      firebaseUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Timeout or error — fall back to checking saved session below.
      firebaseUser = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) return;

    final isLoggedIn = await TokenStorageService.isLoggedIn();
    final savedUserId = await TokenStorageService.getUserId();
    final hasLocalSession =
        isLoggedIn && savedUserId != null && savedUserId.isNotEmpty;

    if (firebaseUser != null || hasLocalSession) {
      // ── Force-refresh the token BEFORE navigating ─────────────────────────
      // This ensures the cart's very first API call uses a fresh token,
      // not a stale one from the previous app session.
      if (firebaseUser != null) {
        try {
          final freshToken = await firebaseUser.getIdToken(true);
          if (freshToken != null && freshToken.isNotEmpty) {
            await TokenStorageService.saveIdToken(freshToken);
            debugPrint('✅ Splash: token force-refreshed before navigation.');
          }
        } catch (e) {
          debugPrint('⚠️ Splash: token refresh failed: $e');
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(MainNavigationScreen.routeName);
    } else {
      Navigator.of(context).pushReplacementNamed(InfoScreen.routeName);
    }
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

