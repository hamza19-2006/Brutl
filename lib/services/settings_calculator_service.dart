import 'package:flutter/foundation.dart';

/// Pure, side-effect-free math used by the Settings module.
///
/// Implements:
/// - Mifflin-St Jeor BMR
/// - Activity multiplier from the user's daily step goal
/// - Body-fat penalty/bonus on top of TDEE
/// - Macro split suggestion (protein-anchored, fat-anchored, carbs filler)
@immutable
class MacroSuggestion {
  const MacroSuggestion({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.maintenanceCalories,
  });

  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int maintenanceCalories;
}

class SettingsCalculatorService {
  const SettingsCalculatorService._();

  /// Mifflin-St Jeor BMR.
  /// gender: "Male" | "Female" | "Other" (Other averages the two formulas).
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required String gender,
  }) {
    final base = 10.0 * weightKg + 6.25 * heightCm - 5.0 * ageYears;
    final g = gender.toLowerCase();
    if (g == 'male' || g == 'm') return base + 5.0;
    if (g == 'female' || g == 'f') return base - 161.0;
    // 'Other' — average the male/female constants for a neutral estimate.
    return base + (5.0 - 161.0) / 2.0;
  }

  /// Activity multiplier based purely on daily step goal as the directive
  /// requires no other lifestyle inputs.
  static double activityMultiplierForSteps(int dailyStepGoal) {
    if (dailyStepGoal < 5000) return 1.20;
    if (dailyStepGoal < 7500) return 1.30;
    if (dailyStepGoal < 10000) return 1.40;
    if (dailyStepGoal < 12500) return 1.55;
    if (dailyStepGoal < 15000) return 1.65;
    return 1.75;
  }

  /// Body-fat penalty/bonus applied multiplicatively to TDEE.
  /// Higher BF% gets a small downward correction (less lean mass).
  static double bodyFatModifier(double bodyFatAverage) {
    if (bodyFatAverage <= 0) return 1.0;
    if (bodyFatAverage <= 12) return 1.05;
    if (bodyFatAverage <= 20) return 1.02;
    if (bodyFatAverage <= 28) return 1.0;
    if (bodyFatAverage <= 35) return 0.97;
    return 0.94;
  }

  /// Returns the maintenance calories (TDEE) before any cut/bulk goal is
  /// applied.
  static int maintenanceCalories({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required String gender,
    required int dailyStepGoal,
    required double bodyFatAverage,
  }) {
    final basal = bmr(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      gender: gender,
    );
    final tdee =
        basal *
        activityMultiplierForSteps(dailyStepGoal) *
        bodyFatModifier(bodyFatAverage);
    return tdee.round();
  }

  /// Build a balanced macro split anchored on lean mass.
  /// - Protein: 1.8 g per kg of estimated lean mass (fallback 1.6 g/kg total).
  /// - Fat: 25% of total calories.
  /// - Carbs: remainder of the calorie budget.
  static MacroSuggestion suggestMacros({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required String gender,
    required int dailyStepGoal,
    required double bodyFatAverage,
    required String bodyGoal,
  }) {
    final maintenance = maintenanceCalories(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      gender: gender,
      dailyStepGoal: dailyStepGoal,
      bodyFatAverage: bodyFatAverage,
    );

    int target;
    switch (bodyGoal.toLowerCase()) {
      case 'cut':
      case 'fat loss':
      case 'lose':
        target = (maintenance - 400).round();
        break;
      case 'bulk':
      case 'gain':
      case 'muscle gain':
        target = (maintenance + 300).round();
        break;
      default:
        target = maintenance;
    }
    if (target < 1200) target = 1200;

    final leanMassKg = bodyFatAverage > 0
        ? weightKg * (1 - bodyFatAverage / 100)
        : weightKg * 0.78;
    final proteinGrams = (leanMassKg > 0 ? leanMassKg * 1.8 : weightKg * 1.6)
        .round();
    final fatCalories = target * 0.25;
    final fatGrams = (fatCalories / 9.0).round();
    final proteinCalories = proteinGrams * 4;
    final carbsCalories = (target - proteinCalories - (fatGrams * 9))
        .clamp(0, target)
        .toDouble();
    final carbsGrams = (carbsCalories / 4.0).round();

    return MacroSuggestion(
      calories: target,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      maintenanceCalories: maintenance,
    );
  }
}
