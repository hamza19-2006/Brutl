import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../services/step_service.dart';
import '../models/brutl_models.dart' as brutl;
import '../models/user_data_models.dart';

class WorkoutProvider extends ChangeNotifier {
  static const String _userPrefsKey = 'brutl_user_model';
  static const String _workoutPlanPrefsKey = 'brutl_workout_plan_model';
  static const String _workoutHistoryBoxName = 'brutl_workout_history';
  static const String _defaultWorkoutSplit = 'Upper/Lower';
  static const Map<String, List<String>> _splitTemplates =
      <String, List<String>>{
        'Upper/Lower': <String>['Upper A', 'Lower A', 'Upper B', 'Lower B'],
        'Push/Pull/Legs': <String>[
          'Push',
          'Pull',
          'Legs',
          'Push',
          'Pull',
          'Legs',
        ],
        'Bro Split': <String>['Chest', 'Back', 'Legs', 'Shoulders', 'Arms'],
      };

  UserModel _user = const UserModel(
    id: 'local-athlete',
    name: 'Brutl',
    dailyCalorieGoal: 500,
    weightKg: 70.0,
  );

  // Program-Style state
  int _selectedWeek = 1;
  final int _totalProgramWeeks = 4;
  String _selectedWorkoutSplit = _defaultWorkoutSplit;
  List<String> _masterTemplate = const <String>[];
  List<String> _customSplitDays = const <String>[];
  Map<String, brutl.ProgramDayModel> _selectedWeekOverrides =
      <String, brutl.ProgramDayModel>{};
  List<brutl.ProgramDayModel> _programDays = <brutl.ProgramDayModel>[];

  WorkoutPlanModel _workoutPlan = WorkoutPlanModel.defaultPlan();
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
  List<ExerciseModel> _topVolumeExercises = const <ExerciseModel>[];
  String? _lastSessionDayName;
  String? _highlightedExerciseName;
  int _currentDailySteps = 0;
  double _currentDailyCaloriesBurned = 0;
  bool _isLoading = true;
  bool _isInitialized = false;
  Box<dynamic>? _workoutHistoryBox;

  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;
  StreamSubscription<BoxEvent>? _exercisesBoxSubscription;

  UserModel get user => _user;
  WorkoutPlanModel get workoutPlan => _workoutPlan;
  List<ExerciseModel> get topVolumeExercises => _topVolumeExercises;
  bool get isLoading => _isLoading;
  String? get highlightedExerciseName => _highlightedExerciseName;
  HomeUiModel get homeUi => _homeUi;
  int get currentDailySteps => _currentDailySteps;
  double get currentDailyCaloriesBurned => _currentDailyCaloriesBurned;

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

  List<brutl.ProgramDayModel> get currentWeekWorkouts {
    final baseList = _programDays
        .where((day) => day.weekNumber == _selectedWeek)
        .toList();
    baseList.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return baseList
        .map((baseDay) {
          final override = _selectedWeekOverrides[baseDay.id];
          if (override == null) return baseDay;
          return baseDay.copyWith(exercises: override.exercises);
        })
        .toList(growable: false);
  }

  void selectWeek(int week) {
    if (_selectedWeek != week) {
      _selectedWeek = week;
      unawaited(_loadWeekOverridesForSelectedWeek());
      notifyListeners();
    }
  }

  String get lastWorkoutTitle => _homeUi.lastWorkoutTitle;
  String get noWorkoutMessage => _homeUi.noWorkoutMessage;

  String get lastWorkoutSubtitle {
    final dayName =
        _lastSessionDayName ?? DateFormat('EEEE').format(DateTime.now());
    return '${_homeUi.lastWorkoutSubtitlePrefix} $dayName ${_homeUi.lastWorkoutSubtitleSuffix}';
  }

  String workoutNameForWeekday(int weekday) =>
      _workoutPlan.workoutForWeekday(weekday);

  double _toKg(double weight, String unit) {
    return unit.toLowerCase() == 'lbs' ? weight * 0.45359237 : weight;
  }

  String get todayWorkoutName {
    final todayIndex = DateTime.now().weekday - 1;

    if (todayIndex >= 0 && todayIndex < _customSplitDays.length) {
      return _customSplitDays[todayIndex];
    }
    if (_customSplitDays.isNotEmpty) {
      return 'Rest';
    }

    if (todayIndex >= 0 && todayIndex < _masterTemplate.length) {
      return _masterTemplate[todayIndex];
    }
    if (_masterTemplate.isNotEmpty) {
      return 'Rest';
    }

    return workoutNameForWeekday(todayIndex + 1);
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _loadUser(prefs);
    await _loadWorkoutSplit(prefs);
    await _loadWorkoutPlan(prefs);
    _workoutHistoryBox = await Hive.openBox<dynamic>(_workoutHistoryBoxName);

    // Seed dashboard stats from local pedometer cache until Firestore stream arrives.
    final stepService = StepService.instance;
    _currentDailySteps = stepService.getTodaySteps();
    _currentDailyCaloriesBurned = stepService.calculateCalories(
      _currentDailySteps,
    );

    // Sync exercises from server so reinstalling doesn't lose data
    final dbService = DatabaseService();
    await dbService.syncExercisesFromFirestore();

    await refreshLastWorkoutInsights();

    // Initial load of program days
    refreshProgramDays();
    await _loadWeekOverridesForSelectedWeek();

    // Auto-refresh program days if exercises box changes
    final exercisesBox = Hive.box<String>('exercises');
    _exercisesBoxSubscription = exercisesBox.watch().listen((event) {
      refreshProgramDays();
    });

    // Subscribe to Firestore for live user data (step goal, display name, calorie goal)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _userStreamSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists && snapshot.data() != null) {
                final data = snapshot.data()!;
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
                final rawWeight =
                    (data['weight'] as num?)?.toDouble() ?? _user.weightKg;
                final weightUnit =
                    (data['weight_unit'] as String?) ??
                    (data['weightUnit'] as String?) ??
                    'kg';
                final weightKg = _toKg(rawWeight, weightUnit);
                final remoteCurrentSteps =
                    (data['currentSteps'] as num?)?.toInt() ??
                    // Backward compatibility: if a separate step-goal field exists,
                    // treat legacy `dailySteps` as current live steps.
                    ((data.containsKey('step_goal') ||
                            data.containsKey('daily_steps') ||
                            data.containsKey('dailyStepGoal') ||
                            data.containsKey('stepGoal'))
                        ? (data['daily_steps'] as num?)?.toInt() ??
                              (data['dailySteps'] as num?)?.toInt()
                        : null) ??
                    _currentDailySteps;
                final remoteCalories =
                    (data['dailyCaloriesBurned'] as num?)?.toDouble() ??
                    StepService.instance.calculateCalories(remoteCurrentSteps);
                final remoteSplit =
                    (data['workout_split_template'] as String?) ??
                    (data['workoutSplitTemplate'] as String?) ??
                    (data['workoutSplit'] as String?) ??
                    (data['split'] as String?) ??
                    _selectedWorkoutSplit;

                // Extract custom split days from Firestore
                final customSplitDays = <String>[];
                final rawCustomSplitDays =
                    (data['custom_split_days'] as List<dynamic>?) ??
                    (data['customSplitDays'] as List<dynamic>?);
                if (rawCustomSplitDays != null) {
                  customSplitDays.addAll(
                    rawCustomSplitDays.map((e) => e.toString()),
                  );
                }
                final remoteMasterTemplate =
                    ((data['workout_master_template'] as List<dynamic>?) ??
                            (data['workoutMasterTemplate'] as List<dynamic>?))
                        ?.map((item) => item.toString().trim())
                        .where((item) => item.isNotEmpty)
                        .toList(growable: false) ??
                    const <String>[];

                _user = _user.copyWith(
                  name: displayName.isNotEmpty ? displayName : _user.name,
                  dailyStepGoal: stepGoal,
                  dailyCalorieGoal: calorieGoal,
                  weightKg: weightKg,
                );
                _currentDailySteps = remoteCurrentSteps < 0
                    ? 0
                    : remoteCurrentSteps;
                _currentDailyCaloriesBurned = remoteCalories
                    .clamp(0, 5000)
                    .toDouble();
                if (customSplitDays.isNotEmpty) {
                  _customSplitDays = customSplitDays;
                  _masterTemplate = customSplitDays;
                } else if (remoteMasterTemplate.isNotEmpty) {
                  _masterTemplate = remoteMasterTemplate;
                  _customSplitDays = remoteMasterTemplate;
                }

                if (_masterTemplate.isNotEmpty) {
                  _selectedWorkoutSplit = remoteSplit;
                  _programDays = _buildProgramDaysFromTemplate(_masterTemplate);
                } else {
                  _setWorkoutSplit(remoteSplit, persist: false);
                }
                unawaited(prefs.setString(_userPrefsKey, _user.toRawJson()));
                notifyListeners();
              }
            },
            onError: (Object error) {
              debugPrint('WORKOUT_PROVIDER: Firestore stream error — $error');
              // Stream will automatically retry on transient errors
            },
          );
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
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
          _customSplitDays = List<String>.from(
            remoteUser.customSplitDays,
            growable: false,
          );
          _masterTemplate = _customSplitDays;
          if (remoteUser.workoutSplitTemplate.trim().isNotEmpty) {
            _selectedWorkoutSplit = remoteUser.workoutSplitTemplate;
          }
          _programDays = _buildProgramDaysFromTemplate(_masterTemplate);
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

  Future<void> _loadWorkoutPlan(SharedPreferences prefs) async {
    final rawPlan = prefs.getString(_workoutPlanPrefsKey);
    if (rawPlan != null) {
      _workoutPlan = WorkoutPlanModel.fromJson(
        jsonDecode(rawPlan) as Map<String, dynamic>,
      );
      return;
    }

    _workoutPlan = WorkoutPlanModel.defaultPlan();
    await prefs.setString(
      _workoutPlanPrefsKey,
      jsonEncode(_workoutPlan.toJson()),
    );
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
          final remoteTemplate =
              ((data['workout_master_template'] as List<dynamic>?) ??
                      (data['workoutMasterTemplate'] as List<dynamic>?))
                  ?.map((item) => item.toString())
                  .where((item) => item.trim().isNotEmpty)
                  .toList(growable: false);
          final remoteCustomSplitDays =
              ((data['custom_split_days'] as List<dynamic>?) ??
                      (data['customSplitDays'] as List<dynamic>?))
                  ?.map((item) => item.toString())
                  .where((item) => item.trim().isNotEmpty)
                  .toList(growable: false);
          if (remoteCustomSplitDays != null &&
              remoteCustomSplitDays.isNotEmpty) {
            _customSplitDays = remoteCustomSplitDays;
            _masterTemplate = remoteCustomSplitDays;
            _selectedWorkoutSplit =
                (data['workout_split_template'] as String?) ??
                (data['workoutSplitTemplate'] as String?) ??
                _selectedWorkoutSplit;
            _programDays = _buildProgramDaysFromTemplate(_masterTemplate);
            await prefs.setString('brutl_workout_split', _selectedWorkoutSplit);
            return;
          }
          if (remoteTemplate != null && remoteTemplate.isNotEmpty) {
            _masterTemplate = remoteTemplate;
            _customSplitDays = remoteTemplate;
            _selectedWorkoutSplit =
                (data['workout_split_template'] as String?) ??
                (data['workoutSplitTemplate'] as String?) ??
                _defaultWorkoutSplit;
            _programDays = _buildProgramDaysFromTemplate(_masterTemplate);
            await prefs.setString('brutl_workout_split', _selectedWorkoutSplit);
            return;
          }
          final remoteSplit =
              (data['workout_split_template'] as String?) ??
              (data['workoutSplitTemplate'] as String?) ??
              (data['workoutSplit'] as String?) ??
              (data['split'] as String?) ??
              _defaultWorkoutSplit;
          _setWorkoutSplit(remoteSplit, persist: false);
          await prefs.setString('brutl_workout_split', _selectedWorkoutSplit);
          return;
        }
      } catch (error) {
        debugPrint('WORKOUT_PROVIDER: Failed to load workout split — $error');
      }
    }

    final cachedSplit = prefs.getString('brutl_workout_split');
    _setWorkoutSplit(cachedSplit ?? _defaultWorkoutSplit, persist: false);
  }

  void refreshProgramDays() {
    final dbService = DatabaseService();
    final updatedDays = _programDays.map((day) {
      final isRestDay = day.splitName.toLowerCase() == 'rest';
      return day.copyWith(
        exercises: isRestDay
            ? const []
            : dbService.getExercisesForSplit(day.splitName),
      );
    }).toList();

    _programDays = updatedDays;
    notifyListeners();
  }

  void _setWorkoutSplit(String split, {required bool persist}) {
    final normalizedSplit = split.trim().isEmpty ? _defaultWorkoutSplit : split;
    if (_selectedWorkoutSplit == normalizedSplit && _programDays.isNotEmpty) {
      return;
    }
    _selectedWorkoutSplit = normalizedSplit;
    final mappedTemplate = _splitTemplates[_selectedWorkoutSplit];
    _masterTemplate =
        (mappedTemplate ??
                (_customSplitDays.isNotEmpty
                    ? _customSplitDays
                    : _splitTemplates[_defaultWorkoutSplit]!))
            .toList(growable: false);
    if (mappedTemplate != null || _customSplitDays.isEmpty) {
      _customSplitDays = _masterTemplate;
    }
    _programDays = _buildProgramDaysFromTemplate(_masterTemplate);
    if (persist) {
      unawaited(_persistSelectedSplit(_selectedWorkoutSplit));
      unawaited(_persistMasterTemplate(_masterTemplate));
    }
  }

  List<brutl.ProgramDayModel> _buildProgramDaysFromTemplate(List<String> days) {
    final generated = <brutl.ProgramDayModel>[];
    for (var week = 1; week <= _totalProgramWeeks; week++) {
      for (var index = 0; index < days.length; index++) {
        generated.add(
          brutl.ProgramDayModel(
            id: 'week${week}_day${index + 1}',
            weekNumber: week,
            dayNumber: index + 1,
            splitName: days[index],
            exercises: const [],
          ),
        );
      }
    }
    return generated;
  }

  Future<void> _persistSelectedSplit(String split) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('brutl_workout_split', split);
  }

  Future<void> _persistMasterTemplate(List<String> template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'workout_split_template': _selectedWorkoutSplit,
      'workout_master_template': template,
      'custom_split_days': template,
      'workoutMasterTemplate': FieldValue.delete(),
      'customSplitDays': FieldValue.delete(),
      'workoutSplitTemplate': FieldValue.delete(),
      'workoutSplit': FieldValue.delete(),
      'split': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> _loadWeekOverridesForSelectedWeek() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _selectedWeekOverrides = <String, brutl.ProgramDayModel>{};
      notifyListeners();
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workout_day_logs')
          .where('weekNumber', isEqualTo: _selectedWeek)
          .get();

      final overrides = <String, brutl.ProgramDayModel>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final programDay = brutl.ProgramDayModel.fromJson(data);
        overrides[programDay.id] = programDay;
      }
      _selectedWeekOverrides = overrides;
      notifyListeners();
    } catch (error) {
      debugPrint('WORKOUT_PROVIDER: Failed loading week overrides — $error');
    }
  }

  Future<void> refreshLastWorkoutInsights() async {
    final session = _findLastMatchingWeekdaySession(DateTime.now().weekday);
    if (session == null) {
      _topVolumeExercises = const <ExerciseModel>[];
      _lastSessionDayName = null;
      notifyListeners();
      return;
    }

    final sessionDate = DateTime.tryParse(session['date'].toString());
    _lastSessionDayName = sessionDate == null
        ? DateFormat('EEEE').format(DateTime.now())
        : DateFormat('EEEE').format(sessionDate);

    final exercises = _parseExercises(session['exercises']);
    _topVolumeExercises = topExercisesByVolume(exercises, limit: 3);
    notifyListeners();
  }

  Future<void> saveWorkoutSession({
    required DateTime date,
    required List<ExerciseModel> exercises,
  }) async {
    final box = _workoutHistoryBox;
    if (box == null || !box.isOpen) {
      throw StateError('Workout history storage is not available.');
    }

    final sessionPayload = <String, dynamic>{
      'date': date.toIso8601String(),
      'weekday': date.weekday,
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
    };

    final key = 'session_${date.toIso8601String()}';
    await box.put(key, sessionPayload);
    await _persistDailyLogIfAvailable(date, exercises);
    await refreshLastWorkoutInsights();
  }

  Future<void> _persistDailyLogIfAvailable(
    DateTime date,
    List<ExerciseModel> exercises,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final selectedDay = currentWeekWorkouts.where(
      (day) => day.dayNumber == date.weekday,
    );
    if (selectedDay.isEmpty) return;
    final day = selectedDay.first;
    final payload = day.toJson()
      ..['exercises'] = exercises.map((exercise) => exercise.toJson()).toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('workout_day_logs')
        .doc(day.id)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> updateUser({
    String? name,
    int? dailyStepGoal,
    int? dailyCalorieGoal,
  }) async {
    final updatedUser = _user.copyWith(
      name: name,
      dailyStepGoal: dailyStepGoal,
      dailyCalorieGoal: dailyCalorieGoal,
    );

    _user = updatedUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, _user.toRawJson());
    notifyListeners();
  }

  void setHighlightedExercise(String? exerciseName) {
    _highlightedExerciseName = exerciseName;
    notifyListeners();
  }

  List<ExerciseModel> topExercisesByVolume(
    List<ExerciseModel> exercises, {
    int limit = 3,
  }) {
    final sorted = List<ExerciseModel>.from(exercises)
      ..sort(
        (a, b) =>
            calculateExerciseVolume(b).compareTo(calculateExerciseVolume(a)),
      );

    return sorted.take(limit).toList(growable: false);
  }

  double calculateExerciseVolume(ExerciseModel exercise) {
    return exercise.weight * exercise.sets * exercise.averageReps;
  }

  List<ExerciseModel> _parseExercises(dynamic rawExercises) {
    if (rawExercises is! List<dynamic>) {
      return const <ExerciseModel>[];
    }

    return rawExercises
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (exercise) =>
              ExerciseModel.fromJson(Map<String, dynamic>.from(exercise)),
        )
        .toList(growable: false);
  }

  Map<String, dynamic>? _findLastMatchingWeekdaySession(int weekday) {
    final box = _workoutHistoryBox;
    if (box == null || !box.isOpen) {
      return null;
    }

    final sessions = box.values
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((session) => (session['weekday'] as num?)?.toInt() == weekday)
        .toList(growable: false);

    if (sessions.isEmpty) {
      return null;
    }

    sessions.sort((a, b) {
      final left =
          DateTime.tryParse(a['date'].toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          DateTime.tryParse(b['date'].toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });

    return sessions.first;
  }

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    _exercisesBoxSubscription?.cancel();
    super.dispose();
  }
}
