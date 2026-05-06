import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/responsive.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isExpanded;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isExpanded = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.yellow : Colors.white,
        foregroundColor: isPrimary ? AppColors.onPrimary : AppColors.textPrimary,
        padding: EdgeInsets.symmetric(
          vertical: Responsive.height(context, 0.018),
          horizontal: Responsive.width(context, 0.04),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        elevation: isPrimary ? 1 : 0,
        textStyle: AppTextStyles.button,
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
            )
          : Text(label),
    );

    if (isExpanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }
}


