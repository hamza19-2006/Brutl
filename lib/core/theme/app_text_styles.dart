import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static TextStyle displayLarge({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
      );

  static TextStyle displayMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      );

  static TextStyle headingLarge({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
      );

  static TextStyle headingMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle headingSmall({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle bodyLarge({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle bodyMedium({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle bodySmall({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle labelLarge({Color color = AppColors.textTertiary}) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.3,
      );

  static TextStyle labelSmall({Color color = AppColors.textTertiary}) =>
      GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  static TextStyle accentLabel({Color color = AppColors.accentPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.0,
      );
}
