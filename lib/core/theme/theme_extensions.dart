import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// BuildContext extensions for ergonomic access to Brutl design tokens.
extension BrutlThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  AppTokens get brutl => const AppTokens();
}

/// Token bundle exposed through BuildContext for consistent UI composition.
final class AppTokens {
  const AppTokens();

  AppColorsPalette get colors => const AppColorsPalette();

  AppSpacingScale get spacing => const AppSpacingScale();

  AppRadiusScale get radius => const AppRadiusScale();

  AppGradientsPalette get gradients => const AppGradientsPalette();

  AppShadows get shadows => const AppShadows();
}

final class AppColorsPalette {
  const AppColorsPalette();

  Color get bg1 => AppColors.backgroundPrimary;
  Color get bg2 => AppColors.backgroundSecondary;
  Color get bg3 => AppColors.backgroundTertiary;
  Color get bg4 => AppColors.backgroundQuaternary;

  Color get borderSubtle => AppColors.borderSubtle;
  Color get border => AppColors.borderDefault;
  Color get borderStrong => AppColors.borderStrong;
  Color get borderAccent => AppColors.borderAccent;

  Color get accent => AppColors.accentPrimary;
  Color get accentSecondary => AppColors.accentSecondary;
  Color get accentSoft => AppColors.accentSoft;
  Color get accentGlow => AppColors.accentGlow;

  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textTertiary => AppColors.textTertiary;
  Color get textDisabled => AppColors.textDisabled;

  Color get success => AppColors.statusSuccess;
  Color get warning => AppColors.statusWarning;
  Color get error => AppColors.statusError;
  Color get info => AppColors.statusInfo;
}

final class AppSpacingScale {
  const AppSpacingScale();

  double get xs => AppSpacing.xs;
  double get sm => AppSpacing.sm;
  double get md => AppSpacing.md;
  double get lg => AppSpacing.lg;
  double get xl => AppSpacing.xl;
  double get xxl => AppSpacing.xxl;
  double get xxxl => AppSpacing.xxxl;
}

final class AppRadiusScale {
  const AppRadiusScale();

  double get sm => AppSpacing.borderRadiusSmall;
  double get md => AppSpacing.borderRadiusMedium;
  double get lg => AppSpacing.borderRadiusLarge;
  double get xl => AppSpacing.borderRadiusXL;
  double get xxl => AppSpacing.borderRadiusXXL;
  double get full => AppSpacing.borderRadiusFull;
}

final class AppGradientsPalette {
  const AppGradientsPalette();

  LinearGradient get accent => AppGradients.accentGradient;
  LinearGradient get accentVertical => AppGradients.accentGradientVertical;
  LinearGradient get cardOverlay => AppGradients.cardOverlayGradient;
  LinearGradient get subtleSurface => AppGradients.subtleGradientBackground;
}

final class AppShadows {
  const AppShadows();

  BoxShadow get primaryCta => const BoxShadow(
    color: Color(0x40FF3D00),
    blurRadius: 20,
    offset: Offset(0, 8),
  );

  BoxShadow get highlightedCardGlow => const BoxShadow(
    color: AppColors.accentGlow,
    blurRadius: 16,
    spreadRadius: 0,
  );
}

extension BrutlTypographyX on BuildContext {
  TextStyle get displayLarge => AppTextStyles.displayLarge();
  TextStyle get displayMedium => AppTextStyles.displayMedium();
  TextStyle get headingLarge => AppTextStyles.headingLarge();
  TextStyle get headingMedium => AppTextStyles.headingMedium();
  TextStyle get headingSmall => AppTextStyles.headingSmall();
  TextStyle get bodyLarge => AppTextStyles.bodyLarge();
  TextStyle get bodyMedium => AppTextStyles.bodyMedium();
  TextStyle get bodySmall => AppTextStyles.bodySmall();
  TextStyle get labelLarge => AppTextStyles.labelLarge();
  TextStyle get labelSmall => AppTextStyles.labelSmall();
  TextStyle get accentLabel => AppTextStyles.accentLabel();
}
