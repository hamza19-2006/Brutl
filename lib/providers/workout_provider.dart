import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/brutl_models.dart' as brutl;
import '../models/user_data_models.dart';
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

  // Computed (NOT stored canonical exercise data) — derived from the local
  // exercises Hive box that is itself a synced cache of Firestore.
  List<ExerciseModel> _topVolumeExercises = const <ExerciseModel>[];
  String? _lastSessionDayName;
  String? _highlightedExerciseName;

  int _currentDailySteps = 0;
  double _currentDailyCaloriesBurned = 0;
  bool _isLoading = true;
  bool _isInitialized = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userStreamSubscription;
  StreamSubscription<BoxEvent>? _exercisesBoxSubscription;

  // ── Public getters ─────────────────────────────────────────────────────────

  UserModel get user => _user;
  HomeUiModel get homeUi => _homeUi;
  bool get isLoading => _isLoading;
  int get currentDailySteps => _currentDailySteps;
  double get currentDailyCaloriesBurned => _currentDailyCaloriesBurned;

  String? get highlightedExerciseName => _highlightedExerciseName;
  List<ExerciseModel> get topVolumeExercises => _topVolumeExercises;

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

  // Backward-compat: orphaned EditExercisesScreen still references this.
  // Always empty — exercises live in Firestore, not in this provider.
  List<brutl.ProgramDayModel> get programDays =>
      const <brutl.ProgramDayModel>[];

  // ── Home strings ───────────────────────────────────────────────────────────

  String get lastWorkoutTitle => _homeUi.lastWorkoutTitle;
  String get noWorkoutMessage => _homeUi.noWorkoutMessage;

  String get lastWorkoutSubtitle {
    final dayName =
        _lastSessionDayName ?? DateFormat('EEEE').format(DateTime.now());
    return '${_homeUi.lastWorkoutSubtitlePrefix} $dayName '
        '${_homeUi.lastWorkoutSubtitleSuffix}';
  }

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
    _currentDailyCaloriesBurned =
        stepService.calculateCalories(_currentDailySteps);

    // Sync the local exercises Hive cache from Firestore so the home
    // last-workout widget has data immediately, even offline.
    final dbService = DatabaseService();
    await dbService.syncExercisesFromFirestore();
    await refreshLastWorkoutInsights();

    // Refresh home insights whenever the local exercises box changes.
    final exercisesBox = Hive.box<String>('exercises');
    _exercisesBoxSubscription = exercisesBox.watch().listen((_) {
      unawaited(refreshLastWorkoutInsights());
    });

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
    final displayName = (data['display_name'] as String?) ??
        (data['displayName'] as String?) ??
        _user.name;
    final stepGoal = (data['step_goal'] as num?)?.toInt() ??
        (data['dailyStepGoal'] as num?)?.toInt() ??
        (data['stepGoal'] as num?)?.toInt() ??
        (data['daily_steps'] as num?)?.toInt() ??
        _user.dailyStepGoal;
    final calorieGoal = (data['target_calories'] as num?)?.toInt() ??
        (data['targetCalories'] as num?)?.toInt() ??
        _user.dailyCalorieGoal;
    final rawWeight =
        (data['weight'] as num?)?.toDouble() ?? _user.weightKg;
    final weightUnit = (data['weight_unit'] as String?) ??
        (data['weightUnit'] as String?) ??
        'kg';
    final weightKg = _toKg(rawWeight, weightUnit);

    final remoteCurrentSteps =
        (data['currentSteps'] as num?)?.toInt() ?? _currentDailySteps;
    final remoteCalories =
        (data['dailyCaloriesBurned'] as num?)?.toDouble() ??
            StepService.instance.calculateCalories(remoteCurrentSteps);

    final remoteSplit = (data['workout_split_template'] as String?) ??
        (data['workoutSplitTemplate'] as String?) ??
        (data['workoutSplit'] as String?) ??
        (data['split'] as String?) ??
        _selectedWorkoutSplit;

    final customDays = _stringList(
          data['custom_split_days'] ?? data['customSplitDays'],
        ) ??
        const <String>[];
    final masterDays = _stringList(
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
      final remoteUser =
          await DatabaseService().fetchUserProfile(firebaseUser.uid);
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

          final customDays = _stringList(
                data['custom_split_days'] ?? data['customSplitDays'],
              ) ??
              const <String>[];
          final masterDays = _stringList(
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
        debugPrint(
          'WORKOUT_PROVIDER: Failed to load workout split — $error',
        );
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

  // ── Home: last-workout insights ────────────────────────────────────────────

  Future<void> refreshLastWorkoutInsights() async {
    final todayName = todayWorkoutName;
    if (todayName.isEmpty || todayName.toLowerCase() == 'rest') {
      _topVolumeExercises = const <ExerciseModel>[];
      _lastSessionDayName = null;
      notifyListeners();
      return;
    }

    final brutlExercises = DatabaseService().getExercisesForSplit(todayName);
    _lastSessionDayName = todayName;
    _topVolumeExercises = _topByVolume(brutlExercises, limit: 3);
    notifyListeners();
  }

  List<ExerciseModel> _topByVolume(
    List<brutl.ExerciseModel> exercises, {
    int limit = 3,
  }) {
    final converted = exercises.map(_toUiExercise).toList(growable: false);
    final sorted = List<ExerciseModel>.from(converted)
      ..sort((a, b) => _volume(b).compareTo(_volume(a)));
    return sorted.take(limit).toList(growable: false);
  }

  ExerciseModel _toUiExercise(brutl.ExerciseModel e) {
    final cleanedWeight = e.weight.replaceAll(RegExp(r'[^0-9.]'), '');
    final parsedWeight = double.tryParse(cleanedWeight) ?? 0.0;
    return ExerciseModel(
      name: e.name,
      sets: e.sets,
      reps: e.repValues,
      weight: parsedWeight,
      imageUrl: '',
    );
  }

  double _volume(ExerciseModel e) {
    if (e.reps.isEmpty) return 0;
    final avgReps = e.reps.reduce((a, b) => a + b) / e.reps.length;
    return e.weight * e.sets * avgReps;
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

  // ── Backward-compatibility stubs ───────────────────────────────────────────
  //
  // The legacy `EditExercisesScreen` (now orphaned, replaced by the
  // Firestore-backed flow inside `edit_days_screen.dart`) still references
  // these. Stubs return empty / no-op so the app compiles even if that
  // screen lingers in the tree. Real exercise mutations now happen
  // directly against Firestore from each screen.

  List<brutl.ProgramDayModel> getDaysForWeek(int weekIndex) =>
      const <brutl.ProgramDayModel>[];

  Future<void> renameDayOptimistic(
    int weekIndex,
    String oldName,
    String newName,
  ) async {}

  Future<void> clearExercisesFromDayOptimistic(
    int weekIndex,
    String dayName,
  ) async {}

  Future<void> renameExerciseOptimistic(
    int weekIndex,
    String dayName,
    String oldExerciseName,
    String newExerciseName,
  ) async {}

  Future<void> deleteExerciseOptimistic(
    int weekIndex,
    String dayName,
    String exerciseName,
  ) async {}

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

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    _exercisesBoxSubscription?.cancel();
    super.dispose();
  }
}
