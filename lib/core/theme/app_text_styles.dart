import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Brutl typography scale powered by Poppins.
///
/// Use these semantic text styles to keep hierarchy consistent and avoid
/// ad-hoc font overrides in feature screens.
final class AppTextStyles {
  const AppTextStyles._();

  /// Hero metrics and high-emphasis numbers.
  static TextStyle displayLarge({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
      );

  /// Page titles and section hero headers.
  static TextStyle displayMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      );

  /// Section headings and dominant card titles.
  static TextStyle headingLarge({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
      );

  /// Item-level headings and exercise titles.
  static TextStyle headingMedium({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      );

  /// Compact headings and grouped list labels.
  static TextStyle headingSmall({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0,
      );

  /// Main body copy.
  static TextStyle bodyLarge({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  /// Default body content.
  static TextStyle bodyMedium({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  /// Supporting and compact descriptions.
  static TextStyle bodySmall({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0,
      );

  /// Chips, tags, and labels.
  static TextStyle labelLarge({Color color = AppColors.textTertiary}) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.3,
      );

  /// Captions and metadata.
  static TextStyle labelSmall({Color color = AppColors.textTertiary}) =>
      GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      );

  /// Accent labels for active and highlighted states.
  static TextStyle accentLabel({Color color = AppColors.accentPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.0,
      );
}
