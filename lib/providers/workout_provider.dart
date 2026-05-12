import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/brutl_models.dart';
import '../models/user_data_models.dart' hide ExerciseModel;
import '../services/database_service.dart';
import '../services/step_service.dart';
import 'nutrition_service.dart';

/// Brutl `WorkoutProvider`
/// -------------------------------------------------------------------------
/// Exercises NEVER live in this provider. They live ONLY in Firestore at:
///
///   users/{uid}/weeks/week_{n}/days/day_{n}    fields: exercises, updatedAt
///
/// This provider only owns:
///   * The user dashboard meta (name, step / calorie goals, weight, etc.)
///   * The selected week (1..N) and total program weeks
///   * The split day-name list (e.g. ['Push', 'Pull', 'Legs'])
///   * UI state (highlighted exercise, last-workout insights for Home)
///
/// All exercise reads/writes are performed by the screens that need them
/// directly against Firestore using `merge: true` + `updatedAt`.
class WorkoutProvider extends ChangeNotifier {
  static const String _userPrefsKey = 'brutl_user_model';
  static const String _splitPrefsKey = 'brutl_workout_split';
  static const String _defaultWorkoutSplit = 'Upper/Lower';

  // ── State ──────────────────────────────────────────────────────────────────

  UserModel _user = const UserModel(
    id: 'local-athlete',
    name: 'Brutl',
    dailyCalorieGoal: 500,
    weightKg: 70.0,
  );

  int _selectedWeek = 1;
  final int _totalProgramWeeks = 4;
  String _selectedWorkoutSplit = _defaultWorkoutSplit;
  List<String> _masterTemplate = const <String>[];
  List<String> _customSplitDays = const <String>[];

  final HomeUiModel _homeUi = const HomeUiModel(
    brandName: 'Brutl',
    daySuffix: 'Day',
    stepsLabel: 'Steps',
    stepsUnitLabel: 'steps',
    caloriesLabel: 'Calories',
    caloriesUnitLabel: 'kcal',
    navigationLabels: <String>['Home', 'Workout', 'Shop', 'Chat'],
    lastWorkoutTitle: 'Last Workout',
    noWorkoutMessage: 'No workout recorded yet. Start your first session!',
    lastWorkoutSubtitlePrefix: 'From your previous',
    lastWorkoutSubtitleSuffix: 'session',
    workoutTabTitle: 'Workout',
    workoutFocusPrompt:
        'Select an exercise from Last Workout to focus your session.',
    focusedExercisePrefix: 'Focused exercise:',
    setsLabel: 'Sets',
    repsLabel: 'Reps',
    weightLabel: 'Weight',
    weightUnit: 'kg',
  );

  String? _highlightedExerciseName;

  int _currentDailySteps = 0;
  double _currentDailyCaloriesBurned = 0;
  bool _isLoading = true;
  bool _isInitialized = false;
  int _exerciseCacheVersion = 0;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userStreamSubscription;

  // ── Public getters ─────────────────────────────────────────────────────────

  UserModel get user => _user;
  HomeUiModel get homeUi => _homeUi;
  bool get isLoading => _isLoading;
  int get currentDailySteps => _currentDailySteps;
  double get currentDailyCaloriesBurned => _currentDailyCaloriesBurned;
  int get exerciseCacheVersion => _exerciseCacheVersion;

  String? get highlightedExerciseName => _highlightedExerciseName;

  int get selectedWeek => _selectedWeek;
  int get totalProgramWeeks => _totalProgramWeeks;
  String get selectedWorkoutSplit => _selectedWorkoutSplit;

  List<String> get customSplitDays =>
      List<String>.unmodifiable(_customSplitDays);

  List<String> get activeSplitDays {
    if (_customSplitDays.isNotEmpty) {
      return List<String>.unmodifiable(_customSplitDays);
    }
    return List<String>.unmodifiable(_masterTemplate);
  }

  // ── Home strings ───────────────────────────────────────────────────────────

  String get lastWorkoutTitle => _homeUi.lastWorkoutTitle;
  String get noWorkoutMessage => _homeUi.noWorkoutMessage;

  String get lastWorkoutSubtitle =>
      '${_homeUi.lastWorkoutSubtitlePrefix} $todayWorkoutName '
      '${_homeUi.lastWorkoutSubtitleSuffix}';

  String get todayWorkoutName {
    final todayIndex = DateTime.now().weekday - 1;
    if (todayIndex >= 0 && todayIndex < _customSplitDays.length) {
      return _customSplitDays[todayIndex];
    }
    if (_customSplitDays.isNotEmpty) return 'Rest';
    if (todayIndex >= 0 && todayIndex < _masterTemplate.length) {
      return _masterTemplate[todayIndex];
    }
    return 'Rest';
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _loadUser(prefs);
    await _loadWorkoutSplit(prefs);

    final stepService = StepService.instance;
    _currentDailySteps = stepService.getTodaySteps();
    _currentDailyCaloriesBurned = stepService.calculateCalories(
      _currentDailySteps,
    );

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _userStreamSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen(
            (snapshot) {
              if (!snapshot.exists || snapshot.data() == null) return;
              _applyFirestoreUserData(snapshot.data()!, prefs);
              notifyListeners();
            },
            onError: (Object error) {
              debugPrint('WORKOUT_PROVIDER: Firestore stream error — $error');
            },
          );
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Force-reload the user metadata + split day list. Called by login and
  /// onboarding flows so the Home screen never paints stale defaults.
  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadUser(prefs);
    await _loadWorkoutSplit(prefs);
    notifyListeners();
  }

  // ── Firestore user-doc syncing ─────────────────────────────────────────────

  void _applyFirestoreUserData(
    Map<String, dynamic> data,
    SharedPreferences prefs,
  ) {
    final displayName =
        (data['display_name'] as String?) ??
        (data['displayName'] as String?) ??
        _user.name;
    final stepGoal =
        (data['step_goal'] as num?)?.toInt() ??
        (data['dailyStepGoal'] as num?)?.toInt() ??
        (data['stepGoal'] as num?)?.toInt() ??
        (data['daily_steps'] as num?)?.toInt() ??
        _user.dailyStepGoal;
    final calorieGoal =
        (data['target_calories'] as num?)?.toInt() ??
        (data['targetCalories'] as num?)?.toInt() ??
        _user.dailyCalorieGoal;
    final rawWeight = (data['weight'] as num?)?.toDouble() ?? _user.weightKg;
    final weightUnit =
        (data['weight_unit'] as String?) ??
        (data['weightUnit'] as String?) ??
        'kg';
    final weightKg = _toKg(rawWeight, weightUnit);

    final remoteCurrentSteps =
        (data['currentSteps'] as num?)?.toInt() ?? _currentDailySteps;
    final remoteCalories =
        (data['dailyCaloriesBurned'] as num?)?.toDouble() ??
        StepService.instance.calculateCalories(remoteCurrentSteps);

    final remoteSplit =
        (data['workout_split_template'] as String?) ??
        (data['workoutSplitTemplate'] as String?) ??
        (data['workoutSplit'] as String?) ??
        (data['split'] as String?) ??
        _selectedWorkoutSplit;

    final customDays =
        _stringList(data['custom_split_days'] ?? data['customSplitDays']) ??
        const <String>[];
    final masterDays =
        _stringList(
          data['workout_master_template'] ?? data['workoutMasterTemplate'],
        ) ??
        const <String>[];

    _user = _user.copyWith(
      name: displayName.isNotEmpty ? displayName : _user.name,
      dailyStepGoal: stepGoal,
      dailyCalorieGoal: calorieGoal,
      weightKg: weightKg,
    );
    _currentDailySteps = remoteCurrentSteps < 0 ? 0 : remoteCurrentSteps;
    _currentDailyCaloriesBurned = remoteCalories.clamp(0, 5000).toDouble();
    _selectedWorkoutSplit = remoteSplit;

    if (customDays.isNotEmpty) {
      _customSplitDays = customDays;
      _masterTemplate = customDays;
    } else if (masterDays.isNotEmpty) {
      _customSplitDays = masterDays;
      _masterTemplate = masterDays;
    }

    unawaited(prefs.setString(_userPrefsKey, _user.toRawJson()));
  }

  Future<void> _loadUser(SharedPreferences prefs) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final remoteUser = await DatabaseService().fetchUserProfile(
        firebaseUser.uid,
      );
      if (remoteUser != null) {
        _user = UserModel(
          id: remoteUser.uid,
          name: remoteUser.displayName.isNotEmpty
              ? remoteUser.displayName
              : (remoteUser.username.isNotEmpty
                    ? remoteUser.username
                    : 'Brutl'),
          dailyStepGoal: remoteUser.dailySteps,
          dailyCalorieGoal: remoteUser.targetCalories,
          weightKg: _toKg(remoteUser.weight, remoteUser.weightUnit),
        );
        if (remoteUser.customSplitDays.isNotEmpty) {
          _customSplitDays = List<String>.unmodifiable(
            remoteUser.customSplitDays,
          );
          _masterTemplate = _customSplitDays;
          if (remoteUser.workoutSplitTemplate.trim().isNotEmpty) {
            _selectedWorkoutSplit = remoteUser.workoutSplitTemplate;
          }
        }
        await prefs.setString(_userPrefsKey, _user.toRawJson());
        return;
      }
    }

    final rawUser = prefs.getString(_userPrefsKey);
    if (rawUser != null) {
      _user = UserModel.fromRawJson(rawUser);
      return;
    }

    _user = const UserModel(
      id: 'local-athlete',
      name: 'Brutl',
      dailyCalorieGoal: 500,
      weightKg: 70.0,
    );
    await prefs.setString(_userPrefsKey, _user.toRawJson());
  }

  Future<void> _loadWorkoutSplit(SharedPreferences prefs) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;

          final customDays =
              _stringList(
                data['custom_split_days'] ?? data['customSplitDays'],
              ) ??
              const <String>[];
          final masterDays =
              _stringList(
                data['workout_master_template'] ??
                    data['workoutMasterTemplate'],
              ) ??
              const <String>[];

          _selectedWorkoutSplit =
              (data['workout_split_template'] as String?) ??
              (data['workoutSplitTemplate'] as String?) ??
              _defaultWorkoutSplit;

          if (customDays.isNotEmpty) {
            _customSplitDays = customDays;
            _masterTemplate = customDays;
          } else if (masterDays.isNotEmpty) {
            _customSplitDays = masterDays;
            _masterTemplate = masterDays;
          }

          await prefs.setString(_splitPrefsKey, _selectedWorkoutSplit);
          return;
        }
      } catch (error) {
        debugPrint('WORKOUT_PROVIDER: Failed to load workout split — $error');
      }
    }

    _selectedWorkoutSplit =
        prefs.getString(_splitPrefsKey) ?? _defaultWorkoutSplit;
  }

  // ── Week selection ─────────────────────────────────────────────────────────

  void selectWeek(int week) {
    if (_selectedWeek == week) return;
    _selectedWeek = week;
    notifyListeners();
  }

  // ── Split mutation (used by SplitChangeScreen) ─────────────────────────────

  /// Replaces the active split with [newDayNames]. Writing to Firestore is
  /// the caller's responsibility — this method only updates in-memory state.
  void wipeAndReplaceSplit(List<String> newDayNames) {
    _customSplitDays = List<String>.unmodifiable(newDayNames);
    _masterTemplate = _customSplitDays;
    _selectedWorkoutSplit = 'Custom';
    notifyListeners();
  }

  Future<void> pruneExerciseFromLocalDayCache({
    required String weekId,
    required String dayId,
    String? exerciseId,
    String? exerciseName,
  }) async {
    final normalizedId = exerciseId?.trim().toLowerCase() ?? '';
    final normalizedName = exerciseName?.trim().toLowerCase() ?? '';
    if (normalizedId.isEmpty && normalizedName.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _dayExercisePrefsKey(weekId, dayId);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return;
    }

    final pruned = decoded
        .where((entry) {
          if (entry is! Map) {
            return true;
          }
          final map = Map<String, dynamic>.from(entry);
          final currentId = (map['id']?.toString().trim().toLowerCase()) ?? '';
          final currentName =
              (map['name']?.toString().trim().toLowerCase()) ?? '';
          final isIdMatch =
              normalizedId.isNotEmpty && currentId == normalizedId;
          final isNameMatch =
              normalizedName.isNotEmpty && currentName == normalizedName;
          return !(isIdMatch || isNameMatch);
        })
        .toList(growable: false);

    if (pruned.length == decoded.length) {
      return;
    }

    await prefs.setString(key, jsonEncode(pruned));
    _exerciseCacheVersion += 1;
    notifyListeners();
  }

  Future<void> clearLocalDayExerciseCache({
    required String weekId,
    required String dayId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dayExercisePrefsKey(weekId, dayId);
    await prefs.setString(key, jsonEncode(const <dynamic>[]));
    _exerciseCacheVersion += 1;
    notifyListeners();
  }

  Future<List<ExerciseModel>> importPreviousWeekExercises({
    required String uid,
    required int currentWeek,
    required int currentDayId,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty || currentWeek <= 0 || currentDayId <= 0) {
      return const <ExerciseModel>[];
    }

    var targetWeek = currentWeek - 1;
    if (currentWeek == 1) {
      targetWeek = 4;
    }

    final firestore = FirebaseFirestore.instance;
    final sourceDayRef = firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('weeks')
        .doc('week_$targetWeek')
        .collection('days')
        .doc('day_$currentDayId');

    final targetDayRef = firestore
        .collection('users')
        .doc(normalizedUid)
        .collection('weeks')
        .doc('week_$currentWeek')
        .collection('days')
        .doc('day_$currentDayId');

    final sourceSnapshot = await sourceDayRef.get();
    final sourceData = sourceSnapshot.data();
    final rawExercises =
        (sourceData?['exercises'] as List<dynamic>?) ?? const <dynamic>[];
    final copiedExercises = rawExercises
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);

    if (copiedExercises.isEmpty) {
      return const <ExerciseModel>[];
    }

    final batch = firestore.batch();
    batch.set(targetDayRef, <String, dynamic>{
      'exercises': copiedExercises,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _dayExercisePrefsKey(
      'week_$currentWeek',
      'day_$currentDayId',
    );
    await prefs.setString(cacheKey, jsonEncode(copiedExercises));

    _exerciseCacheVersion += 1;
    notifyListeners();

    return copiedExercises
        .map((entry) => ExerciseModel.fromJson(entry))
        .toList(growable: false);
  }

  // ── User mutations ─────────────────────────────────────────────────────────

  void setHighlightedExercise(String? exerciseName) {
    _highlightedExerciseName = exerciseName;
    notifyListeners();
  }

  Future<void> updateUser({
    String? name,
    int? dailyStepGoal,
    int? dailyCalorieGoal,
  }) async {
    _user = _user.copyWith(
      name: name,
      dailyStepGoal: dailyStepGoal,
      dailyCalorieGoal: dailyCalorieGoal,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, _user.toRawJson());
    notifyListeners();
  }

  /// Synchronously updates local calorie/macro targets so Home and Workout
  /// screens repaint immediately, then fans out to NutritionService and
  /// SharedPreferences without blocking the UI.
  void updateOptimisticMacros(
    int newKcal,
    int newCarbs,
    int newProtein,
    int newFat,
  ) {
    _user = _user.copyWith(dailyCalorieGoal: newKcal);

    unawaited(
      NutritionService.instance.saveGoals(
        calorieGoal: newKcal,
        carbsGoal: newCarbs,
        proteinGoal: newProtein,
        fatsGoal: newFat,
      ),
    );

    unawaited(
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.setInt('calorie_goal', newKcal);
        await prefs.setInt('carbs_goal', newCarbs);
        await prefs.setInt('protein_goal', newProtein);
        await prefs.setInt('fats_goal', newFat);
        await prefs.setString(_userPrefsKey, _user.toRawJson());
      }),
    );

    notifyListeners();
  }

  /// Public alias used by the settings macros flow.
  void forceUpdateMacros(
    int newKcal,
    int newCarbs,
    int newProtein,
    int newFats,
  ) {
    updateOptimisticMacros(newKcal, newCarbs, newProtein, newFats);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _toKg(double weight, String unit) =>
      unit.toLowerCase() == 'lbs' ? weight * 0.45359237 : weight;

  List<String>? _stringList(Object? raw) {
    if (raw is! List) return null;
    final result = raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return result.isEmpty ? const <String>[] : result;
  }

  String _dayExercisePrefsKey(String weekId, String dayId) =>
      'exercises_day_${dayId}_week_${weekId}';

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    super.dispose();
  }
}
