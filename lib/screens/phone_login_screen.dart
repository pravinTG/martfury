import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import '../services/auth_service.dart';
import 'verify_otp_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneLoginScreen extends StatefulWidget {
  static const String routeName = '/phone-login';

  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String phoneNumber = _phoneController.text.trim();
      
      // Remove any spaces or special characters except digits
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      // If phone number already starts with country code (starts with +91 or 91)
      if (phoneNumber.startsWith('91') && phoneNumber.length >= 12) {
        phoneNumber = '+$phoneNumber';
      } else if (phoneNumber.startsWith('+91')) {
        // Already has +91
        phoneNumber = phoneNumber;
      } else if (!phoneNumber.startsWith('+')) {
        // Add +91 prefix for Indian numbers
        phoneNumber = '+91$phoneNumber';
      }
      
      print('📱 Formatted Phone Number: $phoneNumber');

      // Send OTP using Firebase Auth
      await _authService.firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _authService.firebaseAuth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          _showError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          Navigator.of(context).pushNamed(
            VerifyOTPScreen.routeName,
            arguments: {
              'verificationId': verificationId,
              'phoneNumber': phoneNumber,
            },
          );
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
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacing.sizedBoxH32,
                Text(
                  'Login with Phone',
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacing.sizedBoxH8,
                Text(
                  'Enter your phone number to receive an OTP code',
                  style: AppTextStyles.body2,
                ),
                Spacing.sizedBoxH48,
                Text(
                  'Phone Number',
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacing.sizedBoxH8,
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: AppTextStyles.body2,
                    prefix: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        '+91',
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.phone, color: AppColors.textSecondary),
                    ),
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
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    // Remove non-digits for validation
                    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                    if (digitsOnly.length < 10) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    if (digitsOnly.length > 10) {
                      // If user entered with country code, check total length
                      if (digitsOnly.length < 12 || !digitsOnly.startsWith('91')) {
                        return 'Please enter a valid phone number';
                      }
                    }
                    return null;
                  },
                ),
                Spacing.sizedBoxH32,
                AppButton(
                  label: _isLoading ? 'Sending OTP...' : 'Send OTP',
                  onPressed: _isLoading ? null : _sendOTP,
                ),
                Spacing.sizedBoxH24,
                Center(
                  child: Text(
                    'We will send you a verification code via SMS',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

