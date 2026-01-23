import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomSnackBar {
  static void success(String message) {
    // This will be shown via ScaffoldMessenger in the context
    // For now, we'll use a simple implementation
  }

  static void error(String message) {
    // This will be shown via ScaffoldMessenger in the context
    // For now, we'll use a simple implementation
  }

  static void show(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}


