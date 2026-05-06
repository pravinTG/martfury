import 'package:flutter/material.dart';
import 'package:martfury/theme/app_colors.dart';

enum AppSnackType { success, error, info }

class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.info,
  }) {
    final color = switch (type) {
      AppSnackType.success => AppColors.success,
      AppSnackType.error => AppColors.error,
      AppSnackType.info => AppColors.primary,
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
