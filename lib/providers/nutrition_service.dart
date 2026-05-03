import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class MealData {
  const MealData({
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fats,
  });

  final String name;
  final int calories;
  final int carbs;
  final int protein;
  final int fats;

  MealData copyWith({int? calories, int? carbs, int? protein, int? fats}) {
    return MealData(
      name: name,
      calories: calories ?? this.calories,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fats: fats ?? this.fats,
    );
  }
}

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
    required this.meals,
  });

  final int caloriesEaten;
  final int calorieGoal;
  final int carbs;
  final int carbsGoal;
  final int protein;
  final int proteinGoal;
  final int fats;
  final int fatsGoal;
  final List<MealData> meals;
}

class NutritionService {
  NutritionService._();

  static final NutritionService instance = NutritionService._();

  static const List<String> mealNames = [
    'Breakfast',
    'Lunch',
    'Snack',
    'Dinner',
  ];

  // Total daily keys
  static const String _caloriesKey = 'today_calories_eaten';
  static const String _calorieGoalKey = 'calorie_goal';
  static const String _carbsKey = 'today_carbs';
  static const String _carbsGoalKey = 'carbs_goal';
  static const String _proteinKey = 'today_protein';
  static const String _proteinGoalKey = 'protein_goal';
  static const String _fatsKey = 'today_fats';
  static const String _fatsGoalKey = 'fats_goal';

  // Date key for midnight reset
  static const String _nutritionDateKey = 'nutrition_date';

  // Per-meal keys: meal_breakfast_calories, meal_lunch_calories, etc.
  static String _mealKey(String meal, String field) =>
      'meal_${meal.toLowerCase()}_$field';

  final StreamController<NutritionData> _controller =
      StreamController<NutritionData>.broadcast();

  Stream<NutritionData> get stream => _controller.stream;

  String _todayStamp() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<NutritionData> loadTodayNutrition() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetIfNewDay(prefs);
    return _buildFromPrefs(prefs);
  }

  Future<void> _checkAndResetIfNewDay(SharedPreferences prefs) async {
    final storedDate = prefs.getString(_nutritionDateKey) ?? '';
    final today = _todayStamp();
    if (storedDate != today) {
      await _resetAll(prefs, today);
    }
  }

  Future<void> _resetAll(SharedPreferences prefs, String today) async {
    await prefs.setString(_nutritionDateKey, today);
    await prefs.setInt(_caloriesKey, 0);
    await prefs.setInt(_carbsKey, 0);
    await prefs.setInt(_proteinKey, 0);
    await prefs.setInt(_fatsKey, 0);
    for (final meal in mealNames) {
      await prefs.setInt(_mealKey(meal, 'calories'), 0);
      await prefs.setInt(_mealKey(meal, 'carbs'), 0);
      await prefs.setInt(_mealKey(meal, 'protein'), 0);
      await prefs.setInt(_mealKey(meal, 'fats'), 0);
    }
  }

  NutritionData _buildFromPrefs(SharedPreferences prefs) {
    final meals = mealNames.map((name) {
      return MealData(
        name: name,
        calories: prefs.getInt(_mealKey(name, 'calories')) ?? 0,
        carbs: prefs.getInt(_mealKey(name, 'carbs')) ?? 0,
        protein: prefs.getInt(_mealKey(name, 'protein')) ?? 0,
        fats: prefs.getInt(_mealKey(name, 'fats')) ?? 0,
      );
    }).toList();

    return NutritionData(
      caloriesEaten: prefs.getInt(_caloriesKey) ?? 0,
      calorieGoal: prefs.getInt(_calorieGoalKey) ?? 2000,
      carbs: prefs.getInt(_carbsKey) ?? 0,
      carbsGoal: prefs.getInt(_carbsGoalKey) ?? 200,
      protein: prefs.getInt(_proteinKey) ?? 0,
      proteinGoal: prefs.getInt(_proteinGoalKey) ?? 150,
      fats: prefs.getInt(_fatsKey) ?? 0,
      fatsGoal: prefs.getInt(_fatsGoalKey) ?? 60,
      meals: meals,
    );
  }

  /// Add calories to a specific meal and update totals.
  Future<void> addMealCalories({
    required String mealName,
    required int calories,
    required int carbs,
    required int protein,
    required int fats,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetIfNewDay(prefs);

    final mealCal =
        (prefs.getInt(_mealKey(mealName, 'calories')) ?? 0) + calories;
    final mealCarbs = (prefs.getInt(_mealKey(mealName, 'carbs')) ?? 0) + carbs;
    final mealPro =
        (prefs.getInt(_mealKey(mealName, 'protein')) ?? 0) + protein;
    final mealFat = (prefs.getInt(_mealKey(mealName, 'fats')) ?? 0) + fats;

    await prefs.setInt(_mealKey(mealName, 'calories'), mealCal.clamp(0, 99999));
    await prefs.setInt(_mealKey(mealName, 'carbs'), mealCarbs.clamp(0, 99999));
    await prefs.setInt(_mealKey(mealName, 'protein'), mealPro.clamp(0, 99999));
    await prefs.setInt(_mealKey(mealName, 'fats'), mealFat.clamp(0, 99999));

    final totalCal = (prefs.getInt(_caloriesKey) ?? 0) + calories;
    final totalCarbs = (prefs.getInt(_carbsKey) ?? 0) + carbs;
    final totalPro = (prefs.getInt(_proteinKey) ?? 0) + protein;
    final totalFat = (prefs.getInt(_fatsKey) ?? 0) + fats;

    await prefs.setInt(_caloriesKey, totalCal.clamp(0, 99999));
    await prefs.setInt(_carbsKey, totalCarbs.clamp(0, 99999));
    await prefs.setInt(_proteinKey, totalPro.clamp(0, 99999));
    await prefs.setInt(_fatsKey, totalFat.clamp(0, 99999));

    final data = _buildFromPrefs(prefs);
    if (!_controller.isClosed) _controller.add(data);
  }

  /// Legacy: add calories without a specific meal (treated as Breakfast bucket).
  Future<void> addCalories(
    int calories,
    int carbs,
    int protein,
    int fats,
  ) async {
    await addMealCalories(
      mealName: 'Breakfast',
      calories: calories,
      carbs: carbs,
      protein: protein,
      fats: fats,
    );
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
    await _resetAll(prefs, _todayStamp());
    final data = _buildFromPrefs(prefs);
    if (!_controller.isClosed) _controller.add(data);
  }

  void dispose() {
    _controller.close();
  }
}
