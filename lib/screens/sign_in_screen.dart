import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../api_service.dart';
import '../token_storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import 'main_navigation_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  static const String routeName = '/signin';

  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phoneDigits = _phoneController.text.trim();

    if (phoneDigits.length != 10 || !RegExp(r'^\d{10}$').hasMatch(phoneDigits)) {
      _showMessage('Enter valid 10-digit mobile number.');
      return;
    }
    final rawPhone = '+91$phoneDigits';

    setState(() => _isSendingOtp = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: rawPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // If Firebase auto-retrieves the SMS code, we populate the field
          // but DO NOT automatically log in, forcing the user to click "Verify OTP".
          if (credential.smsCode != null) {
            setState(() {
              _isSendingOtp = false;
              _otpController.text = credential.smsCode!;
            });
            _showMessage('OTP received. Please click Verify.');
            return;
          }

          // IF smsCode is null, it means "Instant Verification" happened 
          // (Firebase securely verified the device WITHOUT sending an SMS). 
          // We MUST log them in here, otherwise they will wait for an SMS that never comes!
          setState(() {
            _isSendingOtp = false;
            _isVerifyingOtp = true;
          });
          _showMessage('Device instantly verified by Firebase.');

          try {
            final userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final idToken = await userCredential.user?.getIdToken(true);
            if (idToken != null && idToken.isNotEmpty) {
              await TokenStorageService.saveIdToken(idToken);
              await _loginToBackend(idToken);
            }
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(MainNavigationScreen.routeName);
          } catch (e) {
            if (!mounted) return;
            setState(() => _isVerifyingOtp = false);
            _showMessage('Auto-verification failed.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _isSendingOtp = false);
          _showMessage(e.message ?? 'Phone verification failed.');
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isSendingOtp = false;
          });
          _showMessage('OTP sent successfully.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isSendingOtp = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingOtp = false);
      _showMessage('Failed to send OTP: $e');
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) {
      _showMessage('Please request OTP first.');
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      _showMessage('Enter a valid 6-digit OTP.');
      return;
    }

    setState(() => _isVerifyingOtp = true);
    debugPrint('OTP_VERIFY: started');
    debugPrint('OTP_VERIFY: verificationId=${_verificationId ?? "null"}');
    debugPrint('OTP_VERIFY: enteredOtp=$otp');
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      debugPrint('OTP_VERIFY: credential created');

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('OTP_VERIFY: signInWithCredential success');
      debugPrint('OTP_VERIFY: additionalUserInfo.isNewUser=${userCredential.additionalUserInfo?.isNewUser}');
      debugPrint('OTP_VERIFY: user.uid=${userCredential.user?.uid}');
      debugPrint('OTP_VERIFY: user.phone=${userCredential.user?.phoneNumber}');

      final idToken = await userCredential.user?.getIdToken(true);
      debugPrint('OTP_VERIFY: idTokenLength=${idToken?.length ?? 0}');
      if (idToken != null && idToken.length > 40) {
        debugPrint('OTP_VERIFY: idTokenPreview=${idToken.substring(0, 40)}...');
        await TokenStorageService.saveIdToken(idToken);
        debugPrint('OTP_VERIFY: saved id token');
        await _loginToBackend(idToken);
      } else {
        debugPrint('OTP_VERIFY: idToken is null or too short');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(MainNavigationScreen.routeName);
    } on FirebaseAuthException catch (e) {
      debugPrint('OTP_VERIFY: FirebaseAuthException code=${e.code}');
      debugPrint('OTP_VERIFY: FirebaseAuthException message=${e.message}');
      _showMessage(e.message ?? 'OTP verification failed.');
    } catch (e) {
      debugPrint('OTP_VERIFY: unexpected error=$e');
      _showMessage('OTP verification failed.');
    } finally {
      debugPrint('OTP_VERIFY: completed');
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
      }
    }
  }

  Future<void> _loginToBackend(String idToken) async {
    final response = await _apiService.firebaseLogin(
      idToken: idToken,
      fcmToken: '',
      platform: Platform.operatingSystem,
      osVersion: Platform.operatingSystemVersion,
      appVersion: '1.0.0',
    );

    final user = response['user'];
    final apiUserId = user is Map<String, dynamic>
        ? user['id']?.toString()
        : response['user_id']?.toString() ?? response['id']?.toString();
    if (apiUserId != null && apiUserId.isNotEmpty) {
      await TokenStorageService.saveUserId(apiUserId);
      debugPrint('OTP_VERIFY: saved API user id=$apiUserId');
    } else {
      debugPrint('OTP_VERIFY: API user id missing in response');
    }
  }

  void _showMessage(String message) {
    AppSnackBar.show(context, message, type: AppSnackType.info);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = Responsive.isTablet(context);
        final contentWidth =
        isTablet ? constraints.maxWidth * 0.7 : constraints.maxWidth;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.width(context, 0.08),
                  vertical: Responsive.height(context, 0.02),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo5.png',

                      ),
                      Text(
                        'Sign In',
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Spacing.sizedBoxH8,
                      Text(
                        'Welcome back! Please enter your number',
                        style: AppTextStyles.body2,
                        textAlign: TextAlign.center,
                      ),
                      Spacing.sizedBoxH32,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _verificationId == null ? 'Phone Number' : 'Enter OTP',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Spacing.sizedBoxH8,
                      if (_verificationId == null) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          maxLength: 10,
                          decoration: InputDecoration(
                            hintText: '10-digit mobile number',
                            counterText: '',
                            hintStyle: AppTextStyles.body2,
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              child: Text(
                                '+91',
                                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.transparent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.yellow),
                            ),
                          ),
                        ),
                        Spacing.sizedBoxH12,
                        const SizedBox(height: 20),
                        AppButton(
                          label: _isSendingOtp ? 'Sending OTP...' : 'Send OTP',
                          isLoading: _isSendingOtp,
                          onPressed: _isSendingOtp ? null : _sendOtp,
                        ),
                      ] else ...[
                        Spacing.sizedBoxH16,
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            hintText: '6-digit OTP',
                            counterText: '',
                            hintStyle: AppTextStyles.body2,
                            filled: true,
                            fillColor: const Color(0xFFF8F8F8),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.transparent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.yellow),
                            ),
                          ),
                        ),
                        Spacing.sizedBoxH12,
                        AppButton(
                          label: _isVerifyingOtp ? 'Verifying...' : 'Verify OTP',
                          isLoading: _isVerifyingOtp,
                          onPressed: _isVerifyingOtp ? null : _verifyOtp,
                        ),
                        Spacing.sizedBoxH16,
                      ],
                      // Email/password sign-in section commented as requested.
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: Container(
                      //         height: 1,
                      //         color: const Color(0xFFE0E0E0),
                      //       ),
                      //     ),
                      //     Padding(
                      //       padding: const EdgeInsets.symmetric(horizontal: 12),
                      //       child: Text(
                      //         'Or sign in with email',
                      //         style: AppTextStyles.body2,
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: Container(
                      //         height: 1,
                      //         color: const Color(0xFFE0E0E0),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // Spacing.sizedBoxH20,
                      // Align(
                      //   alignment: Alignment.centerLeft,
                      //   child: Text(
                      //     'Email',
                      //     style: AppTextStyles.body1.copyWith(
                      //       fontWeight: FontWeight.w600,
                      //     ),
                      //   ),
                      // ),
                      // Spacing.sizedBoxH8,
                      // const _EmailField(),
                      // Spacing.sizedBoxH20,
                      // Align(
                      //   alignment: Alignment.centerLeft,
                      //   child: Text(
                      //     'Password',
                      //     style: AppTextStyles.body1.copyWith(
                      //       fontWeight: FontWeight.w600,
                      //     ),
                      //   ),
                      // ),
                      // Spacing.sizedBoxH8,
                      // const _PasswordField(),
                      // Spacing.sizedBoxH8,
                      // Align(
                      //   alignment: Alignment.centerRight,
                      //   child: GestureDetector(
                      //     onTap: () {
                      //       Navigator.of(context).pushNamed(
                      //         ForgotPasswordScreen.routeName,
                      //       );
                      //     },
                      //     child: Text(
                      //       'Forgot Password?',
                      //       style: AppTextStyles.body2.copyWith(
                      //         color: AppColors.yellow,
                      //         fontWeight: FontWeight.w600,
                      //         decoration: TextDecoration.underline,
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Spacing.sizedBoxH32,
                      // AppButton(
                      //   label: 'Sign In',
                      //   onPressed: () {
                      //     Navigator.of(context).pushReplacementNamed(
                      //       MainNavigationScreen.routeName,
                      //     );
                      //   },
                      // ),
                      // Spacing.sizedBoxH24,
                      // Row(
                      //   children: [
                      //     Expanded(
                      //       child: Container(
                      //         height: 1,
                      //         color: const Color(0xFFE0E0E0),
                      //       ),
                      //     ),
                      //     Padding(
                      //       padding: const EdgeInsets.symmetric(horizontal: 12),
                      //       child: Text(
                      //         'Or continue with',
                      //         style: AppTextStyles.body2,
                      //       ),
                      //     ),
                      //     Expanded(
                      //       child: Container(
                      //         height: 1,
                      //         color: const Color(0xFFE0E0E0),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // Spacing.sizedBoxH24,
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //   children: const [
                      //     _SocialBox(),
                      //     _SocialBox(),
                      //     _SocialBox(),
                      //   ],
                      // ),
                      Spacing.sizedBoxH32,
                      SizedBox(height: 20,)
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     Text(
                      //       "'Don't have an account? '",
                      //     style: AppTextStyles.body2,
                      //     ),
                      //     GestureDetector(
                      //       onTap: () {
                      //         Navigator.of(context).pushNamed(
                      //           SignUpScreen.routeName,
                      //         );
                      //       },
                      //       child: Text(
                      //         'Sign Up',
                      //         style: AppTextStyles.body2.copyWith(
                      //           color: AppColors.yellow,
                      //           fontWeight: FontWeight.w600,
                      //           decoration: TextDecoration.underline,
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// class _EmailField extends StatelessWidget {
//   const _EmailField();
//
//   @override
//   Widget build(BuildContext context) {
//     return TextField(
//       keyboardType: TextInputType.emailAddress,
//       decoration: InputDecoration(
//         hintText: 'example@gmail.com',
//         hintStyle: AppTextStyles.body2,
//         filled: true,
//         fillColor: const Color(0xFFF8F8F8),
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 14,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: Colors.transparent),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: AppColors.yellow),
//         ),
//       ),
//     );
//   }
// }
//
// class _PasswordField extends StatelessWidget {
//   const _PasswordField();
//
//   @override
//   Widget build(BuildContext context) {
//     return TextField(
//       obscureText: true,
//       decoration: InputDecoration(
//         hintText: '*****',
//         hintStyle: AppTextStyles.body2,
//         filled: true,
//         fillColor: const Color(0xFFF8F8F8),
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 14,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: AppColors.yellow),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(16),
//           borderSide: const BorderSide(color: AppColors.yellow),
//         ),
//         suffixIcon: const Icon(
//           Icons.visibility_off_outlined,
//           color: Colors.black87,
//         ),
//       ),
//     );
//   }
// }
