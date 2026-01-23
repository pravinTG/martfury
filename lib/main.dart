import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/info_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/category_screen.dart';
import 'screens/phone_login_screen.dart';
import 'screens/verify_otp_screen.dart';
import 'screens/homepage_screen.dart';
import 'screens/main_tabs_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/cart_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Select env file based on APP_ENV dart-define (dev/prod)
  const env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  final envFile = env.toLowerCase() == 'prod' ? '.env.prod' : '.env.dev';

  try {
    await dotenv.load(fileName: envFile);
    print('✅ Loaded environment file: $envFile');
    print('✅ BASE_URL: ${dotenv.env['BASE_URL']}');
  } catch (e) {
    print('⚠️ Failed to load $envFile: $e');
    print('⚠️ Using default values');
    // Continue with defaults - ApiService has fallback values
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MartfuryApp());
}

class MartfuryApp extends StatelessWidget {
  const MartfuryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goodies World',
      theme: AppTheme.lightTheme,
      initialRoute: SplashScreen.routeName,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case SplashScreen.routeName:
            return _fadeRoute(const SplashScreen(), settings);
          case PhoneLoginScreen.routeName:
            return _slideRoute(const PhoneLoginScreen(), settings);
          case VerifyOTPScreen.routeName:
            return _slideRoute(
              const VerifyOTPScreen(),
              settings,
            );
          case HomepageScreen.routeName:
            return _fadeRoute(const HomepageScreen(), settings);
          case MainTabsScreen.routeName:
            return _fadeRoute(const MainTabsScreen(), settings);
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
          case CategoryScreen.routeName:
            return _fadeRoute(const CategoryScreen(), settings);
          case ProductDetailScreen.routeName:
            final args = settings.arguments as Map<String, dynamic>?;
            final productId = args?['productId'] as int? ?? 0;
            return _slideRoute(
              ProductDetailScreen(productId: productId),
              settings,
            );
          case CartScreen.routeName:
            return _fadeRoute(const CartScreen(), settings);
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
