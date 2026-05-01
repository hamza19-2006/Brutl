import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gradient tokens used by core Brutl components.
final class AppGradients {
  const AppGradients._();

  /// Horizontal accent gradient for primary actions and linear progress fills.
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.accentPrimary, AppColors.accentSecondary],
  );

  /// Vertical accent gradient for circular progress rings.
  static const LinearGradient accentGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.accentPrimary, AppColors.accentSecondary],
  );

  /// Overlay used to improve text contrast on image-based cards.
  static const LinearGradient cardOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, AppColors.backgroundPrimary],
  );

  /// Subtle hero surface depth gradient.
  static const LinearGradient subtleGradientBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.backgroundSecondary, Color(0xFF0D0D0D)],
  );
}
