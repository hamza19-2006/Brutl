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

class WorkoutProvider extends ChangeNotifier {
  static const String _userPrefsKey = 'brutl_user_model';
  static const String _splitPrefsKey = 'brutl_workout_split';
  // ── NEW: key to persist when the user started week 1 ──
  static const String _programStartDateKey = 'brutl_program_start_date';
  static const String _defaultWorkoutSplit = 'Upper/Lower';

  // ── State ──────────────────────────────────────────────────────────────────

  UserModel _user = const UserModel(
    id: 'local-athlete',
    name: 'Brutl',
    dailyCalorieGoal: 500,
    weightKg: 70.0,
  );

  // ── CHANGED: _selectedWeek is now the UI-only override; real week comes
  //    from _computeCurrentWeek(). Starts at 0 meaning "use auto".
  int _selectedWeek = 0;
  final int _totalProgramWeeks = 4;
  String _selectedWorkoutSplit = _defaultWorkoutSplit;
  List<String> _masterTemplate = const <String>[];
  List<String> _customSplitDays = const <String>[];

  // ── NEW: when the user's program started (week 1, day 1) ──
  DateTime? _programStartDate;

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

  // ── CHANGED: selectedWeek returns the auto-computed week unless the user
  //    has explicitly overridden it via selectWeek().
  int get selectedWeek =>
      _selectedWeek > 0 ? _selectedWeek : _computeCurrentWeek();

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

  // ── NEW: returns the real current week (1-4 loop) based on program start ──
  int get currentWeekAuto => _computeCurrentWeek();

  int calculateCurrentWeek(DateTime startDate) {
    final now = DateTime.now();

    // 1. Strip time to midnight for accurate day math
    final startMidnight = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final nowMidnight = DateTime(now.year, now.month, now.day);

    // 2. Snap BOTH dates to their respective Mondays (Monday = 1)
    final startMonday = startMidnight.subtract(
      Duration(days: startMidnight.weekday - 1),
    );
    final currentMonday = nowMidnight.subtract(
      Duration(days: nowMidnight.weekday - 1),
    );

    // 3. Calculate how many calendar weeks have passed
    final weeksPassed = currentMonday.difference(startMonday).inDays ~/ 7;

    // 4. Modulo 4 ensures infinite cycle 0,1,2,3 -> 0,1,2,3. Add 1 for the UI.
    return (weeksPassed % 4) + 1;
  }

  int _computeCurrentWeek() {
    final startDate = _programStartDate;
    if (startDate == null) return 1;
    return calculateCurrentWeek(startDate);
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
    await _loadProgramStartDate(prefs);

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

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadUser(prefs);
    await _loadWorkoutSplit(prefs);
    await _loadProgramStartDate(prefs);
    notifyListeners();
  }

  // ── NEW: load/save program start date ──────────────────────────────────────

  Future<void> _loadProgramStartDate(SharedPreferences prefs) async {
    // 1. Try local prefs first (fast)
    final storedStr = prefs.getString(_programStartDateKey);
    if (storedStr != null) {
      _programStartDate = DateTime.tryParse(storedStr);
      if (_programStartDate != null) return;
    }

    // 2. Try Firestore
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _programStartDate ??= DateTime.now();
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data != null) {
        final raw =
            data['program_start_date'] ??
            data['programStartDate'] ??
            data['created_at'] ??
            data['createdAt'];
        DateTime? parsed;
        if (raw is Timestamp) {
          parsed = raw.toDate();
        } else if (raw is String) {
          parsed = DateTime.tryParse(raw);
        }
        if (parsed != null) {
          _programStartDate = parsed;
          await prefs.setString(_programStartDateKey, parsed.toIso8601String());
          return;
        }
      }
    } catch (e) {
      debugPrint('WORKOUT_PROVIDER: could not load program start date — $e');
    }

    // 3. Fallback: treat today as start of the current week block
    //    so the user's current week stays correct.
    _programStartDate ??= DateTime.now();
  }

  // ── NEW: called by onboarding / split-change to record week-1 start ───────
  Future<void> setProgramStartDate(DateTime date) async {
    _programStartDate = date;
    _selectedWeek = 0; // reset override so auto kicks in
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_programStartDateKey, date.toIso8601String());

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(
        FirebaseFirestore.instance.collection('users').doc(uid).set(
          <String, dynamic>{'program_start_date': Timestamp.fromDate(date)},
          SetOptions(merge: true),
        ),
      );
    }
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
    final remoteCalories = StepService.instance.calculateCalories(
      remoteCurrentSteps,
    );

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

    // Also sync program start date if Firestore has it
    final rawStart =
        data['program_start_date'] ??
        data['programStartDate'] ??
        data['created_at'] ??
        data['createdAt'];
    if (rawStart != null && _programStartDate == null) {
      DateTime? parsed;
      if (rawStart is Timestamp) {
        parsed = rawStart.toDate();
      } else if (rawStart is String) {
        parsed = DateTime.tryParse(rawStart);
      }
      if (parsed != null) {
        _programStartDate = parsed;
        unawaited(
          prefs.setString(_programStartDateKey, parsed.toIso8601String()),
        );
      }
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

  // CHANGED: selectWeek now sets an explicit override. When the user
  // navigates away and comes back the auto week is used again.
  void selectWeek(int week) {
    if (_selectedWeek == week) return;
    _selectedWeek = week;
    notifyListeners();
  }

  // ── NEW: reset to auto week (call when leaving Workout tab) ───────────────
  void resetToAutoWeek() {
    if (_selectedWeek == 0) return;
    _selectedWeek = 0;
    notifyListeners();
  }

  // ── Split mutation ─────────────────────────────────────────────────────────

  void wipeAndReplaceSplit(List<String> newDayNames) {
    _customSplitDays = List<String>.unmodifiable(newDayNames);
    _masterTemplate = _customSplitDays;
    _selectedWorkoutSplit = 'Custom';
    // Reset program start to today so week 1 begins fresh
    unawaited(setProgramStartDate(DateTime.now()));
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
