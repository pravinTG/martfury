import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_button.dart';
import '../widgets/spacing.dart';
import '../utils/responsive.dart';
import 'sign_in_screen.dart';

class NewPasswordScreen extends StatelessWidget {
  static const String routeName = '/new-password';

  const NewPasswordScreen({super.key});

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Spacing.sizedBoxH24,
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'Creat New Password',
                              // Keeping typo to match provided UI text
                              style: AppTextStyles.heading1.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Spacing.sizedBoxH8,
                            Text(
                              'Enter your new password and log in\nto your account',
                              style: AppTextStyles.body2,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Spacing.sizedBoxH40,
                      Text(
                        'Password',
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacing.sizedBoxH8,
                      const _PasswordField(),
                      Spacing.sizedBoxH24,
                      Text(
                        'Confirm Password',
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacing.sizedBoxH8,
                      const _PasswordField(),
                      Spacing.sizedBoxH32,
                      AppButton(
                        label: 'Reset Password',
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            SignInScreen.routeName,
                          );
                        },
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



