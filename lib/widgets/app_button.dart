import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/responsive.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isExpanded;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isPrimary = true,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppColors.primary : Colors.white,
        foregroundColor: isPrimary ? Colors.black : AppColors.textPrimary,
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
      onPressed: onPressed,
      child: Text(label),
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




