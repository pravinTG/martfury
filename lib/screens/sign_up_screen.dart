import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatelessWidget {
  static const String routeName = '/signup';

  const SignUpScreen({super.key});

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
                      Spacing.sizedBoxH32,
                      Text(
                        'Creat An Account',
                        // Typo kept to mirror screenshot text
                        style: AppTextStyles.heading1.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Spacing.sizedBoxH8,
                      Text(
                        'Enter your details or sign up with your\nsocial account',
                        style: AppTextStyles.body2,
                        textAlign: TextAlign.center,
                      ),
                      Spacing.sizedBoxH32,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Name',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Spacing.sizedBoxH8,
                      const _TextField(
                        hint: 'ex. John Smith',
                      ),
                      Spacing.sizedBoxH20,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Email',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Spacing.sizedBoxH8,
                      const _TextField(
                        hint: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      Spacing.sizedBoxH20,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password',
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Spacing.sizedBoxH8,
                      const _PasswordField(),
                      Spacing.sizedBoxH32,
                      AppButton(
                        label: 'Sign Up',
                        onPressed: () {
                          // TODO: perform sign up then go to home
                        },
                      ),
                      Spacing.sizedBoxH24,
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE0E0E0),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE0E0E0),
                            ),
                          ),
                        ],
                      ),

                      Spacing.sizedBoxH32,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTextStyles.body2,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacementNamed(
                                SignInScreen.routeName,
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _TextField extends StatelessWidget {
  final String hint;
  final TextInputType keyboardType;

  const _TextField({
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: true,
      decoration: InputDecoration(
        hintText: '************',
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        suffixIcon: const Icon(
          Icons.visibility_off_outlined,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _SocialBox extends StatelessWidget {
  const _SocialBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
    );
  }
}




