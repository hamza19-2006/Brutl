import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_service.dart';
import '../models/brutl_models.dart' as brutl;
import '../models/user_data_models.dart';

class WorkoutProvider extends ChangeNotifier {
  static const String _userPrefsKey = 'brutl_user_model';
  static const String _workoutPlanPrefsKey = 'brutl_workout_plan_model';
  static const String _workoutHistoryBoxName = 'brutl_workout_history';

  UserModel _user = const UserModel(
    id: 'local-athlete',
    name: 'Brutl',
    dailyCalorieGoal: 500,
  );
  
  // Program-Style state
  int _selectedWeek = 1;
  final int _totalProgramWeeks = 4;
  final List<brutl.ProgramDayModel> _programDays = [
    brutl.ProgramDayModel(
      id: 'day1',
      weekNumber: 1,
      dayNumber: 1,
      splitName: 'Upper A',
      exercises: [],
    ),
    brutl.ProgramDayModel(
      id: 'day2',
      weekNumber: 1,
      dayNumber: 2,
      splitName: 'Lower A',
      exercises: [],
    ),
    brutl.ProgramDayModel(
      id: 'day4',
      weekNumber: 1,
      dayNumber: 4,
      splitName: 'Upper B',
      exercises: [],
    ),
    brutl.ProgramDayModel(
      id: 'day5',
      weekNumber: 1,
      dayNumber: 5,
      splitName: 'Lower B',
      exercises: [],
    ),
  ];

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
  bool _isLoading = true;
  bool _isInitialized = false;
  Box<dynamic>? _workoutHistoryBox;

  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;

  UserModel get user => _user;
  WorkoutPlanModel get workoutPlan => _workoutPlan;
  List<ExerciseModel> get topVolumeExercises => _topVolumeExercises;
  bool get isLoading => _isLoading;
  String? get highlightedExerciseName => _highlightedExerciseName;
  HomeUiModel get homeUi => _homeUi;

  int get selectedWeek => _selectedWeek;
  int get totalProgramWeeks => _totalProgramWeeks;

  List<brutl.ProgramDayModel> get currentWeekWorkouts {
    final list = _programDays.where((day) => day.weekNumber == _selectedWeek).toList();
    list.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return list;
  }

  void selectWeek(int week) {
    if (_selectedWeek != week) {
      _selectedWeek = week;
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

  String get todayWorkoutName => workoutNameForWeekday(DateTime.now().weekday);

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _loadUser(prefs);
    await _loadWorkoutPlan(prefs);
    _workoutHistoryBox = await Hive.openBox<dynamic>(_workoutHistoryBoxName);
    await refreshLastWorkoutInsights();

    // Subscribe to Firestore for live user data (step goal, display name, calorie goal)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _userStreamSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data()!;
              final displayName =
                  (data['displayName'] as String?) ?? _user.name;
              final stepGoal =
                  (data['dailySteps'] as num?)?.toInt() ?? _user.dailyStepGoal;
              final calorieGoal =
                  (data['targetCalories'] as num?)?.toInt() ??
                  _user.dailyCalorieGoal;

              _user = _user.copyWith(
                name: displayName.isNotEmpty ? displayName : _user.name,
                dailyStepGoal: stepGoal,
                dailyCalorieGoal: calorieGoal,
              );
              unawaited(prefs.setString(_userPrefsKey, _user.toRawJson()));
              notifyListeners();
            }
          });
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
        );
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
    await refreshLastWorkoutInsights();
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
    super.dispose();
  }
}
