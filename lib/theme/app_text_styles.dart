import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get heading1 => GoogleFonts.workSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading2 => GoogleFonts.workSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get heading3 => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get body1 => GoogleFonts.workSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get body2 => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => GoogleFonts.workSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get hintText => GoogleFonts.workSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.hintText,
  );

  static TextStyle get button => GoogleFonts.workSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
}


