import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base
        .copyWith(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.backgroundPrimary,
          colorScheme: const ColorScheme.dark(
            surface: AppColors.backgroundTertiary,
            primary: AppColors.accentPrimary,
            secondary: AppColors.accentSecondary,
            onSurface: AppColors.textPrimary,
            onPrimary: AppColors.textPrimary,
            outline: AppColors.borderDefault,
            error: AppColors.statusError,
          ),
          cardTheme: CardThemeData(
            color: AppColors.backgroundTertiary,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
              side: const BorderSide(color: AppColors.borderDefault, width: 1),
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: AppColors.backgroundSecondary,
            selectedItemColor: AppColors.accentPrimary,
            unselectedItemColor: AppColors.textTertiary,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.backgroundQuaternary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppSpacing.borderRadiusMedium,
              ),
              borderSide: const BorderSide(color: AppColors.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppSpacing.borderRadiusMedium,
              ),
              borderSide: const BorderSide(color: AppColors.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppSpacing.borderRadiusMedium,
              ),
              borderSide: const BorderSide(
                color: AppColors.accentPrimary,
                width: 1.5,
              ),
            ),
            hintStyle: AppTextStyles.bodyLarge(color: AppColors.textTertiary),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll(
                AppColors.accentPrimary,
              ),
              foregroundColor: const WidgetStatePropertyAll(
                AppColors.textPrimary,
              ),
              elevation: const WidgetStatePropertyAll(0),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              minimumSize: const WidgetStatePropertyAll(
                Size(double.infinity, 56),
              ),
              textStyle: WidgetStatePropertyAll(
                GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
            displayLarge: AppTextStyles.displayLarge(),
            displayMedium: AppTextStyles.displayMedium(),
            headlineLarge: AppTextStyles.headingLarge(),
            headlineMedium: AppTextStyles.headingMedium(),
            headlineSmall: AppTextStyles.headingSmall(),
            bodyLarge: AppTextStyles.bodyLarge(),
            bodyMedium: AppTextStyles.bodyMedium(),
            bodySmall: AppTextStyles.bodySmall(),
            labelLarge: AppTextStyles.labelLarge(),
            labelSmall: AppTextStyles.labelSmall(),
          ),
          dividerTheme: const DividerThemeData(
            color: AppColors.borderSubtle,
            thickness: 1,
            space: 0,
          ),
          iconTheme: const IconThemeData(
            color: AppColors.textPrimary,
            size: 24,
          ),
          splashColor: AppColors.accentGlow,
          highlightColor: AppColors.accentGlow,
          splashFactory: InkRipple.splashFactory,
          extensions: const <ThemeExtension<dynamic>>[],
        )
        .copyWith(
          appBarTheme: base.appBarTheme.copyWith(
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        );
  }

  static LinearGradient get breathingAuthGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF121212)],
  );

  static LinearGradient get heroSurfaceGradient =>
      AppGradients.subtleGradientBackground;
}
