import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import '../utils/safe_print.dart';
import '../utils/custom_snackbar.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'main_tabs_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  static const String routeName = '/verify-otp';

  const VerifyOTPScreen({super.key});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _verificationId;
  String? _phoneNumber;
  int _resendToken = 0;
  int _resendTimer = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _verificationId = args['verificationId'];
      _phoneNumber = args['phoneNumber'];
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_resendTimer > 0) {
            _resendTimer--;
            _startResendTimer();
          } else {
            _canResend = true;
          }
        });
      }
    });
  }

  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6) {
      CustomSnackBar.show(context, 'Please enter a valid 6-digit OTP', isError: true);
      return;
    }

    if (_verificationId == null) {
      CustomSnackBar.show(context, 'Verification ID not found', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Verify OTP with Firebase
      await _authService.verifyOTP(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Step 2: Get FCM Token
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
        safePrint('📲 Generated FCM Token: $fcmToken');
      } catch (e) {
        safePrint('Error getting FCM token: $e');
      }

      // Step 3: Get Firebase User and ID Token
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          CustomSnackBar.show(context, 'Firebase user not found after OTP verification', isError: true);
        }
        return;
      }

      String? idToken = await user.getIdToken();
      safePrint('idToken: $idToken');

      // Step 4: Get Platform Info
      String platform = Platform.isAndroid 
          ? "android" 
          : Platform.isIOS 
              ? "ios" 
              : "unknown";
      String osVersion = Platform.operatingSystemVersion;
      
      // Step 5: Get App Version
      final packageInfo = await PackageInfo.fromPlatform();
      String appVersion = packageInfo.version;

      // Step 6: Prepare request body
      final body = {
        "idToken": idToken,
        "fcm_token": fcmToken ?? "",
        "platform": platform,
        "device_type": "phone",
        "os_version": osVersion,
        "app_version": appVersion,
      };
      safePrint('📄 Response Body: ${body}');

      safePrint('═══════════════════════════════════════');
      safePrint('🔐 OTP VERIFICATION DEBUG INFO');
      safePrint('═══════════════════════════════════════');
      safePrint('📱 Platform: $platform');
      safePrint('📱 OS Version: $osVersion');
      safePrint('📱 App Version: $appVersion');
      safePrint('📱 FCM Token: ${fcmToken ?? "null"}');
      safePrint('🔑 ID Token: ${idToken?.substring(0, 50) ?? "null"}...');
      safePrint('📦 Request Body: ${jsonEncode(body)}');
      safePrint('🌐 API Endpoint: /firebased-login');
      safePrint('🌐 Base URL: ${ApiService.baseUrl}');
      safePrint('═══════════════════════════════════════');

      // Step 7: Call backend API
      safePrint('📡 Sending POST request to backend...');
      final response = await ApiService.posts("/firebased-login", body);
      
      safePrint('═══════════════════════════════════════');
      safePrint('📥 API RESPONSE DEBUG INFO');
      safePrint('═══════════════════════════════════════');
      safePrint('📊 Status Code: ${response.statusCode}');
      safePrint('📋 Response Headers: ${response.headers}');
      safePrint('📄 Response Body: ${response.body}');
      safePrint('📏 Response Body Length: ${response.body.length}');
      safePrint('═══════════════════════════════════════');

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          safePrint('✅ Response parsed successfully');
          safePrint('📊 Response Data: $data');
          safePrint('📊 Status: ${data["status"]}');
          safePrint('📊 User Data: ${data["user"]}');
          
          if (data["status"] == true && data["user"] != null) {
            // Step 8: Store idToken and backendUserId locally
            int backendUserId = data["user"]["id"];
            safePrint('👤 Backend User ID: $backendUserId');
            
            await SessionManager.loginFromWordPress(
              userId: backendUserId,
              token: idToken ?? "",
            );

            safePrint('✅ Login successful - User ID: $backendUserId');
            safePrint('💾 Session saved locally');

            if (mounted) {
              CustomSnackBar.show(context, 'Login Successful!', isError: false);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const MainTabsScreen(),
                ),
              );
            }
          } else {
            safePrint('❌ Login failed - Invalid response structure');
            safePrint('📊 Status: ${data["status"]}');
            safePrint('📊 Message: ${data["message"] ?? "No message"}');
            
            if (mounted) {
              CustomSnackBar.show(
                context,
                data["message"] ?? "Failed to login after OTP verification",
                isError: true,
              );
            }
          }
        } catch (e) {
          safePrint('❌ Error parsing response: $e');
          safePrint('📄 Raw response: ${response.body}');
          
          if (mounted) {
            CustomSnackBar.show(
              context,
              'Invalid response from server. Please try again.',
              isError: true,
            );
          }
        }
      } else {
        safePrint('❌ SERVER ERROR DETECTED');
        safePrint('📊 Status Code: ${response.statusCode}');
        safePrint('📄 Response Body: ${response.body}');
        safePrint('📋 Response Headers: ${response.headers}');
        
        String errorMessage = 'Server error after OTP verification. Please try again.';
        
        // Try to extract error message from response
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'] ?? errorMessage;
          } else if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'] ?? errorMessage;
          }
        } catch (e) {
          safePrint('Could not parse error response: $e');
        }
        
        if (mounted) {
          CustomSnackBar.show(
            context,
            errorMessage,
            isError: true,
          );
        }
      }
    } catch (e, stackTrace) {
      safePrint('═══════════════════════════════════════');
      safePrint('❌ EXCEPTION DURING OTP VERIFICATION');
      safePrint('═══════════════════════════════════════');
      safePrint('🚨 Error Type: ${e.runtimeType}');
      safePrint('🚨 Error Message: $e');
      safePrint('📚 Stack Trace:');
      safePrint(stackTrace);
      safePrint('═══════════════════════════════════════');
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        String errorMessage = 'Invalid OTP. Please try again.';
        if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
          errorMessage = 'Request timeout. Please check your internet connection.';
        } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else if (e.toString().contains('FormatException') || e.toString().contains('JSON')) {
          errorMessage = 'Invalid response from server. Please try again.';
        }
        
        CustomSnackBar.show(
          context,
          errorMessage,
          isError: true,
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_phoneNumber == null || !_canResend) return;

    setState(() {
      _isLoading = true;
      _canResend = false;
      _resendTimer = 60;
    });

    try {
      await _authService.firebaseAuth.verifyPhoneNumber(
        phoneNumber: _phoneNumber!,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _authService.firebaseAuth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          _showError(e.message ?? 'Failed to resend OTP');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            if (resendToken != null) {
              _resendToken = resendToken;
            }
          });
          _startResendTimer();
          _showSuccess('OTP resent successfully');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to resend OTP');
    }
  }

  void _showError(String message) {
    CustomSnackBar.show(context, message, isError: true);
  }

  void _showSuccess(String message) {
    CustomSnackBar.show(context, message, isError: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.width(context, 0.08),
            vertical: Responsive.height(context, 0.02),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacing.sizedBoxH32,
              Text(
                'Verify OTP',
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacing.sizedBoxH8,
              Text(
                'Enter the 6-digit code sent to\n${_phoneNumber ?? "your phone number"}',
                style: AppTextStyles.body2,
              ),
              Spacing.sizedBoxH48,
              Center(
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 60,
                    fieldWidth: 50,
                    activeFillColor: Colors.white,
                    inactiveFillColor: const Color(0xFFF8F8F8),
                    selectedFillColor: Colors.white,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.transparent,
                    selectedColor: AppColors.primary,
                  ),
                  enableActiveFill: true,
                  textStyle: AppTextStyles.heading2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  onCompleted: (value) {
                    _verifyOTP(value);
                  },
                  onChanged: (value) {},
                ),
              ),
              Spacing.sizedBoxH32,
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                )
              else
                AppButton(
                  label: 'Verify OTP',
                  onPressed: () {
                    if (_otpController.text.length == 6) {
                      _verifyOTP(_otpController.text);
                    } else {
                      _showError('Please enter a valid 6-digit OTP');
                    }
                  },
                ),
              Spacing.sizedBoxH24,
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't receive the code?",
                      style: AppTextStyles.body2,
                    ),
                    Spacing.sizedBoxH8,
                    GestureDetector(
                      onTap: _canResend ? _resendOTP : null,
                      child: Text(
                        _canResend
                            ? 'Resend OTP'
                            : 'Resend OTP in ${_resendTimer}s',
                        style: AppTextStyles.body2.copyWith(
                          color: _canResend
                              ? AppColors.primary
                              : AppColors.textDisabled,
                          fontWeight: FontWeight.w600,
                          decoration: _canResend
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

