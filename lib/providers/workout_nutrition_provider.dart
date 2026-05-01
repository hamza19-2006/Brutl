import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/brutl_models.dart';
import '../models/user_model.dart';
import '../repositories/workout_repository.dart';

class WorkoutNutritionProvider extends ChangeNotifier {
  late final WorkoutRepository _repository;

  WorkoutNutritionProvider() {
    _repository = WorkoutRepository();
    _nutrition = _buildNutrition(
      goalCal: 2800,
      mealCalories: orderedMealMap(_ui.mealNames, 0),
    );
    _sessions = const <WorkoutSessionModel>[];
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

  static final RegExp _repsPattern = RegExp(r'^\d+(?:\s*,\s*\d+)*$');

  late NutritionModel _nutrition;
  late List<WorkoutSessionModel> _sessions;
  String _selectedSessionId = 'session_1';
  String _selectedSplit = '';
  int _bottomNavIndex = 1;
  bool _isLoading = true;
  bool _isInitialized = false;

  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;

  WorkoutNutritionUiModel get ui => _ui;
  NutritionModel get nutrition => _nutrition;
  List<WorkoutSessionModel> get sessions =>
      List<WorkoutSessionModel>.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get selectedSessionId => _selectedSessionId;
  String get selectedSplit => _selectedSplit;
  int get bottomNavIndex => _bottomNavIndex;

  WorkoutSessionModel get selectedSession {
    if (_sessions.isEmpty) {
      return WorkoutSessionModel(
        id: 'empty',
        title: 'No Session',
        splits: [
          WorkoutSplitModel(
            type: WorkoutSplitType.chestTriceps,
            title: 'No Split',
            exercises: const [],
            updatedAt: DateTime.now(),
          ),
        ],
      );
    }
    return _sessions.firstWhere(
      (session) => session.id == _selectedSessionId,
      orElse: () => _sessions.first,
    );
  }

  WorkoutSplitModel get currentSplitModel {
    final session = selectedSession;
    return session.splits.firstWhere(
      (split) => split.title == _selectedSplit,
      orElse: () => session.splits.first,
    );
  }

  List<ExerciseModel> get filteredExercises => currentSplitModel.exercises;

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
                _applyRemoteWorkoutTimestamp(snapshot.data()!);
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
    _sessions = _buildSessionsFromUser(brutlUser);

    if (_sessions.isNotEmpty && _sessions.first.splits.isNotEmpty) {
      _selectedSessionId = _sessions.first.id;
      // Preserve selected split if it still exists
      final splitExists = _sessions.first.splits.any(
        (s) => s.title == _selectedSplit,
      );
      if (!splitExists) {
        _selectedSplit = _sessions.first.splits.first.title;
      }
    }
  }

  void _applyRemoteWorkoutTimestamp(Map<String, dynamic> data) {
    final splitName = data['lastWorkoutSplitName'] as String?;
    final updatedAt = data['lastWorkoutUpdatedAt'];
    if (splitName == null || splitName.isEmpty || updatedAt is! Timestamp) {
      return;
    }

    _setUpdatedAtForSplit(splitName, updatedAt.toDate());
  }

  /// Empty state: no sessions, no exercises
  void _applyEmptyState() {
    _sessions = _buildEmptySessions(<String>['Day 1', 'Day 2', 'Day 3']);
    if (_sessions.isNotEmpty && _sessions.first.splits.isNotEmpty) {
      _selectedSessionId = _sessions.first.id;
      _selectedSplit = _sessions.first.splits.first.title;
    }
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

  List<WorkoutSessionModel> _buildSessionsFromUser(BrutlUser user) {
    final splitNames = user.customSplitDays.isNotEmpty
        ? user.customSplitDays
        : _ui.splitTitles.values.toList();

    if (splitNames.isEmpty) {
      return _buildEmptySessions(<String>['Day 1', 'Day 2', 'Day 3']);
    }

    return List<WorkoutSessionModel>.generate(_ui.sessionTitles.length, (
      index,
    ) {
      final sessionNumber = index + 1;
      return WorkoutSessionModel(
        id: 'session_$sessionNumber',
        title: _ui.sessionTitles[index],
        splits: splitNames.map((name) {
          return WorkoutSplitModel(
            type: WorkoutSplitType.chestTriceps,
            title: name,
            exercises: _repository.getExercisesForSplit(name),
            updatedAt: DateTime.now(),
          );
        }).toList(),
      );
    });
  }

  /// Builds sessions with zero exercises — for new users
  List<WorkoutSessionModel> _buildEmptySessions(List<String> splitNames) {
    return List<WorkoutSessionModel>.generate(_ui.sessionTitles.length, (
      index,
    ) {
      final sessionNumber = index + 1;
      return WorkoutSessionModel(
        id: 'session_$sessionNumber',
        title: _ui.sessionTitles[index],
        splits: splitNames.map((name) {
          return WorkoutSplitModel(
            type: WorkoutSplitType.chestTriceps,
            title: name,
            exercises: const <ExerciseModel>[],
            updatedAt: DateTime.now(),
          );
        }).toList(),
      );
    });
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

  void selectSession(String sessionId) {
    WorkoutSessionModel? session;
    for (final item in _sessions) {
      if (item.id == sessionId) {
        session = item;
        break;
      }
    }
    if (session == null) {
      return;
    }
    _selectedSessionId = sessionId;
    if (!session.splits.any((split) => split.title == _selectedSplit)) {
      _selectedSplit = session.splits.first.title;
    }
    notifyListeners();
  }

  void setSelectedSplit(String split) {
    if (!selectedSession.splits.any((item) => item.title == split)) {
      return;
    }
    _selectedSplit = split;
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

  Future<void> addExerciseToSelectedSplit({
    required String name,
    required int sets,
    required String reps,
    required double weight,
  }) async {
    final normalizedName = name.trim();
    final normalizedReps = _normalizeReps(reps);
    if (normalizedName.isEmpty ||
        sets <= 0 ||
        !_isValidReps(normalizedReps) ||
        weight < 0) {
      throw ArgumentError('Invalid exercise values');
    }

    final exercise = ExerciseModel(
      id: 'exercise_${DateTime.now().microsecondsSinceEpoch}',
      name: normalizedName,
      sets: sets,
      reps: normalizedReps,
      weight: weight,
      splitName: _selectedSplit,
    );

    await _repository.saveExercise(exercise);
    _refreshExercisesForCurrentSplit();
    unawaited(_refreshSelectedSplitTimestampFromRemote());
  }

  Future<void> updateExerciseInSelectedSplit({
    required String exerciseId,
    required String name,
    required int sets,
    required String reps,
    required double weight,
  }) async {
    final normalizedName = name.trim();
    final normalizedReps = _normalizeReps(reps);
    if (normalizedName.isEmpty ||
        sets <= 0 ||
        !_isValidReps(normalizedReps) ||
        weight < 0) {
      throw ArgumentError('Invalid exercise values');
    }

    final exercise = ExerciseModel(
      id: exerciseId,
      name: normalizedName,
      sets: sets,
      reps: normalizedReps,
      weight: weight,
      splitName: _selectedSplit,
    );

    await _repository.saveExercise(exercise);
    _refreshExercisesForCurrentSplit();
    unawaited(_refreshSelectedSplitTimestampFromRemote());
  }

  void _refreshExercisesForCurrentSplit() {
    final exercises = _repository.getExercisesForSplit(_selectedSplit);
    _updateCurrentSplitExercises((current) => exercises);
    _setUpdatedAtForSplit(_selectedSplit, DateTime.now());
  }

  void _updateCurrentSplitExercises(
    List<ExerciseModel> Function(List<ExerciseModel> current) update,
  ) {
    final sessionIndex = _sessions.indexWhere(
      (session) => session.id == _selectedSessionId,
    );
    if (sessionIndex == -1) {
      throw StateError('Selected session does not exist');
    }

    final currentSession = _sessions[sessionIndex];
    final splitIndex = currentSession.splits.indexWhere(
      (split) => split.title == _selectedSplit,
    );
    if (splitIndex == -1) {
      throw StateError('Selected split does not exist');
    }

    final currentSplit = currentSession.splits[splitIndex];
    final updatedSplit = currentSplit.copyWith(
      exercises: update(currentSplit.exercises),
      updatedAt: DateTime.now(),
    );

    final updatedSplits = List<WorkoutSplitModel>.from(currentSession.splits);
    updatedSplits[splitIndex] = updatedSplit;

    final updatedSession = currentSession.copyWith(splits: updatedSplits);
    final updatedSessions = List<WorkoutSessionModel>.from(_sessions);
    updatedSessions[sessionIndex] = updatedSession;
    _sessions = updatedSessions;
    notifyListeners();
  }

  Future<void> _refreshSelectedSplitTimestampFromRemote() async {
    final updatedAt = await _repository.getLatestUpdatedAtForSplit(
      _selectedSplit,
    );
    if (updatedAt != null) {
      _setUpdatedAtForSplit(_selectedSplit, updatedAt);
    }
  }

  void _setUpdatedAtForSplit(String splitName, DateTime updatedAt) {
    var didUpdate = false;
    final updatedSessions = _sessions
        .map((session) {
          final updatedSplits = session.splits
              .map((split) {
                if (split.title != splitName) {
                  return split;
                }

                didUpdate = true;
                return split.copyWith(updatedAt: updatedAt);
              })
              .toList(growable: false);

          return session.copyWith(splits: updatedSplits);
        })
        .toList(growable: false);

    if (didUpdate) {
      _sessions = updatedSessions;
      notifyListeners();
    }
  }

  bool _isValidReps(String reps) {
    return _repsPattern.hasMatch(reps);
  }

  String _normalizeReps(String reps) {
    return reps
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');
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
