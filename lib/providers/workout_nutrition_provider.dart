import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/brutl_models.dart';
import '../models/user_model.dart';

class WorkoutNutritionProvider extends ChangeNotifier {
  WorkoutNutritionProvider() {
    _nutrition = _buildNutrition(
      goalCal: 2800,
      mealCalories: orderedMealMap(_ui.mealNames, 0),
    );
  }

  final WorkoutNutritionUiModel _ui = const WorkoutNutritionUiModel(
    screenTitle: 'Workout & Nutrition',
    workoutHistoryTitle: 'Workout History',
    addNewExerciseLabel: 'Add New Ex',
    logNutritionTitle: 'Log Nutrition',
    todaysTotalPrefix: "Today's Total:",
    caloriesLabel: 'Calories',
    calorieUnit: 'kcal',
    gramsUnit: 'g',
    carbsLabel: 'Carbs',
    proteinLabel: 'Protein',
    fatsLabel: 'Fats',
    sessionTitles: <String>['Week 1', 'Week 2', 'Week 3', 'Week 4'],
    splitTitles: <WorkoutSplitType, String>{
      WorkoutSplitType.chestTriceps: 'Chest & Triceps',
      WorkoutSplitType.backBiceps: 'Back & Biceps',
      WorkoutSplitType.legsShoulders: 'Legs & Shoulders',
    },
    mealNames: <String>['Breakfast', 'Lunch', 'Snack', 'Dinner'],
    exerciseNameLabel: 'Exercise Name',
    setsLabel: 'Sets',
    repsLabel: 'Reps',
    weightLabel: 'Weight',
    weightUnit: 'kg',
    saveActionLabel: 'Save',
    cancelActionLabel: 'Cancel',
    addExerciseTitle: 'Add Exercise',
    editExerciseTitle: 'Edit Exercise',
    noExercisesMessage: 'No exercises found for this split.',
    invalidInputMessage: 'Please enter valid values.',
    bottomNavigationLabels: <String>['Home', 'Workout', 'Shop', 'Chat'],
  );

  late NutritionModel _nutrition;
  int _bottomNavIndex = 1;
  bool _isLoading = true;
  bool _isInitialized = false;

  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;

  WorkoutNutritionUiModel get ui => _ui;
  NutritionModel get nutrition => _nutrition;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  int get bottomNavIndex => _bottomNavIndex;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Do an initial read, then subscribe to live updates
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final brutlUser = BrutlUser.fromJson(doc.data()!);
          _applyUserData(brutlUser);
        } else {
          _applyEmptyState();
        }
      } catch (e) {
        debugPrint(e.toString());
        _applyEmptyState();
      }

      // Subscribe to real-time updates so onboarding changes propagate immediately
      _userStreamSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists && snapshot.data() != null) {
                final brutlUser = BrutlUser.fromJson(snapshot.data()!);
                _applyUserData(brutlUser);
                notifyListeners();
              }
            },
            onError: (Object error) {
              debugPrint(
                'WORKOUT_NUTRITION_PROVIDER: Firestore stream error — $error',
              );
              // Maintains last-known state; stream will auto-retry on transient errors
            },
          );
    } else {
      _applyEmptyState();
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Apply BrutlUser data to nutrition model and session/split structure
  void _applyUserData(BrutlUser brutlUser) {
    _nutrition = _buildNutritionCustom(brutlUser);
  }

  /// Empty state: no sessions, no exercises
  void _applyEmptyState() {
    // Empty state logic goes here if needed
  }

  NutritionModel _buildNutritionCustom(BrutlUser user) {
    final mealCalories = orderedMealMap(_ui.mealNames, 0);
    return NutritionModel(
      totalCal: 0,
      goalCal: user.targetCalories,
      carbs: MacroNutrientModel(consumed: 0, goal: user.targetCarbs),
      protein: MacroNutrientModel(consumed: 0, goal: user.targetProtein),
      fats: MacroNutrientModel(consumed: 0, goal: user.targetFats),
      meals: Map<String, int>.unmodifiable(mealCalories),
    );
  }

  void setBottomNavIndex(int value) {
    final maxIndex = _ui.bottomNavigationLabels.length - 1;
    final clamped = value < 0
        ? 0
        : value > maxIndex
        ? maxIndex
        : value;
    if (_bottomNavIndex == clamped) {
      return;
    }
    _bottomNavIndex = clamped;
    notifyListeners();
  }

  Future<void> updateMealCalories({
    required String mealName,
    required int calories,
  }) {
    if (calories < 0) {
      throw ArgumentError.value(calories, 'calories', 'Calories must be >= 0');
    }
    if (!_nutrition.meals.containsKey(mealName)) {
      throw ArgumentError.value(mealName, 'mealName', 'Meal does not exist');
    }

    final updatedMeals = LinkedHashMap<String, int>.from(_nutrition.meals)
      ..[mealName] = calories;
    final totalCal = updatedMeals.values.fold<int>(
      0,
      (acc, value) => acc + value,
    );
    _nutrition = _nutrition.copyWith(
      totalCal: totalCal,
      meals: Map<String, int>.unmodifiable(updatedMeals),
    );
    notifyListeners();
    return Future<void>.value();
  }

  Future<void> addMealMacros({
    required int carbs,
    required int protein,
    required int fats,
  }) {
    if (carbs < 0 || protein < 0 || fats < 0) {
      throw ArgumentError('Macro values must be >= 0');
    }

    _nutrition = _nutrition.copyWith(
      carbs: _nutrition.carbs.copyWith(
        consumed: _nutrition.carbs.consumed + carbs,
      ),
      protein: _nutrition.protein.copyWith(
        consumed: _nutrition.protein.consumed + protein,
      ),
      fats: _nutrition.fats.copyWith(consumed: _nutrition.fats.consumed + fats),
    );
    notifyListeners();
    return Future<void>.value();
  }

  NutritionModel _buildNutrition({
    required int goalCal,
    required Map<String, int> mealCalories,
  }) {
    final normalizedMeals = LinkedHashMap<String, int>.from(mealCalories);
    final totalCal = normalizedMeals.values.fold<int>(
      0,
      (acc, value) => acc + value,
    );

    final carbsGoal = _macroInGrams(goalCal, 0.45, 4);
    final proteinGoal = _macroInGrams(goalCal, 0.35, 4);
    final fatsGoal = _macroInGrams(goalCal, 0.20, 9);

    final carbsConsumed = _macroInGrams(totalCal, 0.45, 4);
    final proteinConsumed = _macroInGrams(totalCal, 0.35, 4);
    final fatsConsumed = _macroInGrams(totalCal, 0.20, 9);

    return NutritionModel(
      totalCal: totalCal,
      goalCal: goalCal,
      carbs: MacroNutrientModel(consumed: carbsConsumed, goal: carbsGoal),
      protein: MacroNutrientModel(consumed: proteinConsumed, goal: proteinGoal),
      fats: MacroNutrientModel(consumed: fatsConsumed, goal: fatsGoal),
      meals: Map<String, int>.unmodifiable(normalizedMeals),
    );
  }

  int _macroInGrams(int totalCalories, double ratio, int caloriesPerGram) {
    return ((totalCalories * ratio) / caloriesPerGram).round();
  }

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    super.dispose();
  }
}
