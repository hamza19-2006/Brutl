import 'package:flutter/material.dart';

/// Centralized color tokens for the Brutl design system.
///
/// Every color is intentionally mapped to a specific semantic role to keep
/// visual hierarchy and depth consistent across all screens.
final class AppColors {
  const AppColors._();

  /// Layer 1: page-level background.
  static const Color backgroundPrimary = Color(0xFF0A0A0A);

  /// Layer 2: section containers and grouped areas.
  static const Color backgroundSecondary = Color(0xFF111111);

  /// Layer 3: cards and primary content surfaces.
  static const Color backgroundTertiary = Color(0xFF1A1A1A);

  /// Layer 4: inputs, chips, and inner elements.
  static const Color backgroundQuaternary = Color(0xFF242424);

  /// Barely visible separators.
  static const Color borderSubtle = Color(0xFF1F1F1F);

  /// Standard card and container border.
  static const Color borderDefault = Color(0xFF2A2A2A);

  /// Strong focus and active borders.
  static const Color borderStrong = Color(0xFF333333);

  /// Accent border at 20% opacity.
  static const Color borderAccent = Color(0x33FF3D00);

  /// Primary brand accent (restricted usage).
  static const Color accentPrimary = Color(0xFFFF3D00);

  /// Secondary accent for gradients only.
  static const Color accentSecondary = Color(0xFFFF6B00);

  /// Accent glow at 10% opacity.
  static const Color accentGlow = Color(0x1AFF3D00);

  /// Accent soft tint at 20% opacity.
  static const Color accentSoft = Color(0x33FF3D00);

  /// Primary readable text.
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary body/supporting text.
  static const Color textSecondary = Color(0xFFAAAAAA);

  /// Captions, labels, placeholder text.
  static const Color textTertiary = Color(0xFF666666);

  /// Disabled/inactive text.
  static const Color textDisabled = Color(0xFF3A3A3A);

  /// Functional success state.
  static const Color statusSuccess = Color(0xFF22C55E);

  /// Functional warning state.
  static const Color statusWarning = Color(0xFFF59E0B);

  /// Functional error state.
  static const Color statusError = Color(0xFFEF4444);

  /// Functional info state.
  static const Color statusInfo = Color(0xFF3B82F6);

  /// Elevated surface shadow (20% black).
  static const Color elevatedShadow = Color(0x33000000);
}
