import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class NutritionData {
  const NutritionData({
    required this.caloriesEaten,
    required this.calorieGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fats,
    required this.fatsGoal,
  });

  final int caloriesEaten;
  final int calorieGoal;
  final int carbs;
  final int carbsGoal;
  final int protein;
  final int proteinGoal;
  final int fats;
  final int fatsGoal;
}

class NutritionService {
  NutritionService._();

  static final NutritionService instance = NutritionService._();

  static const String _caloriesKey = 'today_calories_eaten';
  static const String _calorieGoalKey = 'calorie_goal';
  static const String _carbsKey = 'today_carbs';
  static const String _carbsGoalKey = 'carbs_goal';
  static const String _proteinKey = 'today_protein';
  static const String _proteinGoalKey = 'protein_goal';
  static const String _fatsKey = 'today_fats';
  static const String _fatsGoalKey = 'fats_goal';

  final StreamController<NutritionData> _controller =
      StreamController<NutritionData>.broadcast();

  Stream<NutritionData> get stream => _controller.stream;

  Future<NutritionData> loadTodayNutrition() async {
    final prefs = await SharedPreferences.getInstance();
    return NutritionData(
      caloriesEaten: prefs.getInt(_caloriesKey) ?? 0,
      calorieGoal: prefs.getInt(_calorieGoalKey) ?? 2000,
      carbs: prefs.getInt(_carbsKey) ?? 0,
      carbsGoal: prefs.getInt(_carbsGoalKey) ?? 200,
      protein: prefs.getInt(_proteinKey) ?? 0,
      proteinGoal: prefs.getInt(_proteinGoalKey) ?? 150,
      fats: prefs.getInt(_fatsKey) ?? 0,
      fatsGoal: prefs.getInt(_fatsGoalKey) ?? 60,
    );
  }

  Future<void> addCalories(
    int calories,
    int carbs,
    int protein,
    int fats,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final updatedCalories = (prefs.getInt(_caloriesKey) ?? 0) + calories;
    final updatedCarbs = (prefs.getInt(_carbsKey) ?? 0) + carbs;
    final updatedProtein = (prefs.getInt(_proteinKey) ?? 0) + protein;
    final updatedFats = (prefs.getInt(_fatsKey) ?? 0) + fats;

    await prefs.setInt(_caloriesKey, updatedCalories.clamp(0, 99999));
    await prefs.setInt(_carbsKey, updatedCarbs.clamp(0, 99999));
    await prefs.setInt(_proteinKey, updatedProtein.clamp(0, 99999));
    await prefs.setInt(_fatsKey, updatedFats.clamp(0, 99999));

    final data = NutritionData(
      caloriesEaten: updatedCalories.clamp(0, 99999),
      calorieGoal: prefs.getInt(_calorieGoalKey) ?? 2000,
      carbs: updatedCarbs.clamp(0, 99999),
      carbsGoal: prefs.getInt(_carbsGoalKey) ?? 200,
      protein: updatedProtein.clamp(0, 99999),
      proteinGoal: prefs.getInt(_proteinGoalKey) ?? 150,
      fats: updatedFats.clamp(0, 99999),
      fatsGoal: prefs.getInt(_fatsGoalKey) ?? 60,
    );

    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  Future<void> saveGoals({
    required int calorieGoal,
    required int carbsGoal,
    required int proteinGoal,
    required int fatsGoal,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_calorieGoalKey, calorieGoal);
    await prefs.setInt(_carbsGoalKey, carbsGoal);
    await prefs.setInt(_proteinGoalKey, proteinGoal);
    await prefs.setInt(_fatsGoalKey, fatsGoal);
  }

  Future<void> resetDailyNutrition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_caloriesKey, 0);
    await prefs.setInt(_carbsKey, 0);
    await prefs.setInt(_proteinKey, 0);
    await prefs.setInt(_fatsKey, 0);

    final data = NutritionData(
      caloriesEaten: 0,
      calorieGoal: prefs.getInt(_calorieGoalKey) ?? 2000,
      carbs: 0,
      carbsGoal: prefs.getInt(_carbsGoalKey) ?? 200,
      protein: 0,
      proteinGoal: prefs.getInt(_proteinGoalKey) ?? 150,
      fats: 0,
      fatsGoal: prefs.getInt(_fatsGoalKey) ?? 60,
    );

    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  void dispose() {
    _controller.close();
  }
}
