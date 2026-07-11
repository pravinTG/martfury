import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/info_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'package:device_preview/device_preview.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    DevicePreview(
      enabled: false, // Enable device preview only in debug mode
      builder: (context) => const GoodiesWorldApp(),
    ),
  );
}

class GoodiesWorldApp extends StatelessWidget {
  const GoodiesWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goodies World',
      theme: AppTheme.lightTheme,
      initialRoute: SplashScreen.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case SplashScreen.routeName:
            return _fadeRoute(const SplashScreen(), settings);
          case InfoScreen.routeName:
            return _fadeRoute(const InfoScreen(), settings);
          case OnboardingScreen.routeName:
            return _fadeRoute(const OnboardingScreen(), settings);
          case SignInScreen.routeName:
            return _slideRoute(const SignInScreen(), settings);
          case SignUpScreen.routeName:
            return _slideRoute(const SignUpScreen(), settings);
          case ForgotPasswordScreen.routeName:
            return _slideRoute(const ForgotPasswordScreen(), settings);
          case NewPasswordScreen.routeName:
            return _slideRoute(const NewPasswordScreen(), settings);
          case MainNavigationScreen.routeName:
            return _fadeRoute(const MainNavigationScreen(), settings);
          default:
            return _fadeRoute(const SplashScreen(), settings);
        }
      },
    );
  }
}

PageRoute _fadeRoute(Widget child, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

PageRoute _slideRoute(Widget child, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder: (_, animation, __, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ));
      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}
