import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/brutl_models.dart' as brutl;
import '../../models/user_model.dart';
import '../../providers/ai_coach_provider.dart';
import '../../providers/brutl_user_provider.dart';
import '../../providers/workout_provider.dart';
import '../chat/ai_chat_screen.dart';

class HomeScreenExShow extends StatefulWidget {
  const HomeScreenExShow({super.key});

  @override
  State<HomeScreenExShow> createState() => _HomeScreenExShowState();
}

class _HomeScreenExShowState extends State<HomeScreenExShow> {
  static const String _progressionSplitName = 'home_progression';
  late Future<_ProgressionPayload> _payloadFuture;
  String _payloadCacheKey = '';

  @override
  void initState() {
    super.initState();
    _payloadFuture = _buildPayload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshPayloadIfNeeded();
  }

  void _refreshPayloadIfNeeded() {
    final workoutProvider = context.read<WorkoutProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final splitFingerprint = workoutProvider.activeSplitDays
        .map((day) => day.trim().toLowerCase())
        .join('|');
    // Using selectedWeek allows you to time-travel and test upcoming weeks!
    final nextKey =
        '$uid|${workoutProvider.selectedWeek}|$splitFingerprint|${DateTime.now().weekday}';
    if (nextKey == _payloadCacheKey) return;
    _payloadCacheKey = nextKey;
    _payloadFuture = _buildPayload();
  }

  @override
  Widget build(BuildContext context) {
    final splitSignature = context.select<WorkoutProvider, String>((provider) {
      final splitFingerprint = provider.activeSplitDays
          .map((day) => day.trim().toLowerCase())
          .join('|');
      return '${provider.selectedWeek}|$splitFingerprint';
    });
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final nextKey = '$uid|$splitSignature|${DateTime.now().weekday}';
    if (nextKey != _payloadCacheKey) {
      _payloadCacheKey = nextKey;
      _payloadFuture = _buildPayload();
    }

    return FutureBuilder<_ProgressionPayload>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ProgressionSkeleton();
        }

        if (!snapshot.hasData) {
          return const _ProgressionSkeleton();
        }

        if (snapshot.data!.isRecovery) {
          return _RecoveryProtocol(reason: snapshot.data?.recoveryReason);
        }

        // Beautiful Empty State Fallback
        if (snapshot.data!.isEmptyState) {
          return _EmptyStateCard(
            dayName: snapshot.data!.emptyStateDayName ?? 'this day',
          );
        }

        final items = snapshot.data!.targets;
        return Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TargetCard(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Future<_ProgressionPayload> _buildPayload() async {
    final workoutProvider = context.read<WorkoutProvider>();
    final userModel = context.read<BrutlUserProvider>().user;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final todayIndex = DateTime.now().weekday - 1;
    final splitDays = workoutProvider.activeSplitDays;
    final inBounds = todayIndex >= 0 && todayIndex < splitDays.length;
    final todayName = inBounds ? splitDays[todayIndex] : '';
    final isRestDay = !inBounds || _isRestName(todayName);
    if (isRestDay) {
      return const _ProgressionPayload.recovery('Split says rest day');
    }

    final guaranteedFallback = _buildGuaranteedTemplatePayload(
      todayName: todayName,
      userModel: userModel,
    );

    if (uid == null || uid.isEmpty) {
      return guaranteedFallback;
    }

    try {
      final currentWeekNumber = workoutProvider.selectedWeek;
      final currentDayId = todayIndex + 1;

      final templateExercises = await _loadTemplateExercisesForToday(
        uid: uid,
        todayIndex: todayIndex,
        todayName: todayName,
        currentWeek: currentWeekNumber,
      );
      if (templateExercises.isEmpty) {
        return guaranteedFallback;
      }

      final historyExercises = await _loadPreviousWeekDayExercises(
        uid: uid,
        currentWeekNumber: currentWeekNumber,
        currentDayId: currentDayId,
      );

      // The flawless First Session Builder (No short circuits!)
      if (historyExercises.isEmpty) {
        final parsedTemplate = templateExercises
            .map((raw) => _ExerciseSnapshot.fromMap(raw))
            .where((e) => e.name.trim().isNotEmpty)
            .toList(growable: false);

        final selectedTemplate = _selectExercises(parsedTemplate);

        if (selectedTemplate.isEmpty) {
          final dayNames = [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
          final currentDayName = dayNames[(DateTime.now().weekday - 1) % 7];
          return _ProgressionPayload.emptyState(currentDayName);
        }

        final templateTargets = selectedTemplate
            .map((e) => _toTemplateTarget(exercise: e, user: userModel))
            .toList(growable: false);

        if (templateTargets.isNotEmpty) {
          return _ProgressionPayload(targets: templateTargets);
        }

        final dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        final currentDayName = dayNames[(DateTime.now().weekday - 1) % 7];
        return _ProgressionPayload.emptyState(currentDayName);
      }

      final hydrated = _hydrateExercisesWithHistory(
        templateExercises: templateExercises,
        historyExercises: historyExercises,
      );
      if (hydrated.isEmpty) {
        return guaranteedFallback;
      }

      final selected = _selectExercises(hydrated);
      if (selected.isEmpty) {
        return guaranteedFallback;
      }

      final targets = selected
          .map(
            (e) => _toTarget(
              exercise: e,
              user: userModel,
              mappedWeight: e.weight,
              mappedReps: e.repsRaw,
            ),
          )
          .toList(growable: false);

      if (targets.isEmpty) {
        return guaranteedFallback;
      }

      return _ProgressionPayload(targets: targets);
    } catch (e) {
      debugPrint('HomeScreenExShow Error: $e');
      return guaranteedFallback;
    }
  }

  Future<List<dynamic>> _loadPreviousWeekDayExercises({
    required String uid,
    required int currentWeekNumber,
    required int currentDayId,
  }) async {
    int targetWeek = currentWeekNumber - 1;
    if (targetWeek <= 0) {
      targetWeek = 4; // The infinite mesocycle loop!
    }

    final daySnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc('week_$targetWeek')
        .collection('days')
        .doc('day_$currentDayId')
        .get();

    final rawData = daySnap.data()?['exercises'];
    final rawExercises = rawData is List ? rawData : const <dynamic>[];
    return rawExercises;
  }

  List<_ExerciseSnapshot> _hydrateExercisesWithHistory({
    required List<Map<String, dynamic>> templateExercises,
    required List<dynamic> historyExercises,
  }) {
    if (templateExercises.isEmpty) return const <_ExerciseSnapshot>[];

    final normalizedHistory = historyExercises
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);

    final historyByName = <String, Map<String, dynamic>>{};
    for (final historyData in normalizedHistory) {
      final key = (historyData['name'] ?? '').toString().trim().toLowerCase();
      if (key.isEmpty || historyByName.containsKey(key)) continue;
      historyByName[key] = historyData;
    }

    final hydrated = <_ExerciseSnapshot>[];
    for (var i = 0; i < templateExercises.length; i++) {
      final templateData = templateExercises[i];
      final templateName = (templateData['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final indexedHistory = i < normalizedHistory.length
          ? normalizedHistory[i]
          : const <String, dynamic>{};
      final historyData = historyByName[templateName] ?? indexedHistory;

      // Bulletproof Fallbacks: Hunts down your numbers no matter how Firestore saves them
      final mappedWeight =
          historyData['weight'] ?? historyData['weightDisplay'] ?? 0.0;
      final mappedReps =
          historyData['reps'] ??
          historyData['repsRaw'] ??
          historyData['repsDisplay'] ??
          historyData['topSetReps'] ??
          '';

      final mergedData = <String, dynamic>{
        'name': templateData['name'] ?? historyData['name'] ?? 'Exercise',
        'baseRange': templateData['baseRange'] ?? templateData['base_range'],
        'categoryType':
            templateData['categoryType'] ??
            templateData['category_type'] ??
            historyData['categoryType'] ??
            historyData['category_type'] ??
            historyData['type'] ??
            'isolation',
        'sets': templateData['sets'] ?? historyData['sets'] ?? 1,
        'weight': mappedWeight,
        'reps': mappedReps,
        'weightUnit':
            historyData['weightUnit'] ??
            historyData['weight_unit'] ??
            templateData['weightUnit'] ??
            templateData['weight_unit'] ??
            'Kg',
      };

      hydrated.add(_ExerciseSnapshot.fromMap(mergedData));
    }

    return hydrated
        .where((e) => e.name.trim().isNotEmpty)
        .toList(growable: false);
  }

  _ProgressionPayload _buildGuaranteedTemplatePayload({
    required String todayName,
    required BrutlUser userModel,
  }) {
    final templateExercises = _heuristicTemplateForDay(todayName);
    final parsed = templateExercises
        .whereType<Map>()
        .map((raw) => _ExerciseSnapshot.fromMap(Map<String, dynamic>.from(raw)))
        .where((e) => e.name.trim().isNotEmpty)
        .toList(growable: false);
    final selected = _selectExercises(parsed);
    final source = selected.isNotEmpty ? selected : parsed;
    final resolvedSource = source.isNotEmpty
        ? source
        : _heuristicTemplateForDay('')
              .whereType<Map>()
              .map(
                (raw) =>
                    _ExerciseSnapshot.fromMap(Map<String, dynamic>.from(raw)),
              )
              .toList(growable: false);
    final targets = resolvedSource
        .take(3)
        .map((e) => _toTemplateTarget(exercise: e, user: userModel))
        .toList(growable: false);
    return _ProgressionPayload(targets: targets);
  }

  Future<List<Map<String, dynamic>>> _loadTemplateExercisesForToday({
    required String uid,
    required int todayIndex,
    required String todayName,
    required int currentWeek,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final weekRefs = <DocumentReference<Map<String, dynamic>>>[
      firestore
          .collection('users')
          .doc(uid)
          .collection('weeks')
          .doc('week_$currentWeek')
          .collection('days')
          .doc('day_${todayIndex + 1}'),
      firestore
          .collection('users')
          .doc(uid)
          .collection('weeks')
          .doc('week_1')
          .collection('days')
          .doc('day_${todayIndex + 1}'),
    ];

    for (final ref in weekRefs) {
      final fromDay = await _loadExercisesFromDayDoc(ref);
      if (fromDay.isNotEmpty) return fromDay;
    }

    final fromWorkouts = await _loadExercisesFromWorkoutCollection(
      uid: uid,
      todayName: todayName,
    );
    if (fromWorkouts.isNotEmpty) return fromWorkouts;

    return _heuristicTemplateForDay(todayName);
  }

  Future<List<Map<String, dynamic>>> _loadExercisesFromDayDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await ref.get();
    final rawData = snap.data()?['exercises'];
    final raw = rawData is List ? rawData : const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['name']?.toString().trim().isNotEmpty ?? false))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadExercisesFromWorkoutCollection({
    required String uid,
    required String todayName,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .where('splitName', isEqualTo: todayName)
          .limit(24)
          .get();
      return snap.docs
          .map((d) => d.data())
          .where((e) => (e['name']?.toString().trim().isNotEmpty ?? false))
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _heuristicTemplateForDay(String todayName) {
    final normalized = todayName.toLowerCase();

    List<Map<String, dynamic>> byNames(List<String> names) {
      return names
          .map(
            (name) => <String, dynamic>{
              'name': name,
              'sets': 3,
              'reps': '',
              'weight': 0,
              'weightUnit': 'Kg',
              'categoryType': _looksCompound(name) ? 'compound' : 'isolation',
            },
          )
          .toList(growable: false);
    }

    if (normalized.contains('chest') || normalized.contains('push')) {
      return byNames(const <String>[
        'Bench Press',
        'Incline Dumbbell Press',
        'Triceps Pushdown',
      ]);
    }
    if (normalized.contains('back') || normalized.contains('pull')) {
      return byNames(const <String>[
        'Barbell Row',
        'Lat Pulldown',
        'Dumbbell Curl',
      ]);
    }
    if (normalized.contains('leg') || normalized.contains('lower')) {
      return byNames(const <String>[
        'Back Squat',
        'Romanian Deadlift',
        'Leg Extension',
      ]);
    }
    if (normalized.contains('shoulder') || normalized.contains('upper')) {
      return byNames(const <String>[
        'Overhead Press',
        'Seated Cable Row',
        'Lateral Raise',
      ]);
    }
    if (normalized.contains('arm')) {
      return byNames(const <String>[
        'Barbell Curl',
        'Skull Crusher',
        'Hammer Curl',
      ]);
    }

    return byNames(const <String>['Goblet Squat', 'Push Up', 'Dumbbell Row']);
  }

  _TargetCardData _toTemplateTarget({
    required _ExerciseSnapshot exercise,
    required BrutlUser user,
  }) {
    final parsedRange = _parseBaseRange(exercise.baseRangeString);
    final lowerLimit = parsedRange.min;
    final upperLimit = parsedRange.max;

    final unit = exercise.weightUnit.trim().isEmpty
        ? user.weightUnit
        : exercise.weightUnit;

    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final currentDayName = dayNames[(DateTime.now().weekday - 1) % 7];

    return _TargetCardData(
      name: exercise.name,
      isCompound: exercise.isCompound,
      lastWeight: 0,
      lastReps: 0,
      lastRepsRaw: '',
      targetWeight: 0,
      targetReps: '$lowerLimit-$upperLimit',
      weightUnit: unit,
      actionLabel: 'Base range: $lowerLimit-$upperLimit reps',
      aiPayload: _toAiExercisePayload(exercise),
      isFirstSession: true,
      lastWeekDisplay: 'Nothing logged last $currentDayName.',
      targetDisplay:
          'Start your first session! Target: $lowerLimit-$upperLimit reps.',
    );
  }

  static bool _looksCompound(String name) {
    final n = name.trim().toLowerCase();
    return n.contains('bench') ||
        n.contains('squat') ||
        n.contains('deadlift') ||
        n.contains('row') ||
        n.contains('press') ||
        n.contains('pull up') ||
        n.contains('pulldown');
  }

  List<_ExerciseSnapshot> _selectExercises(List<_ExerciseSnapshot> source) {
    final sorted = List<_ExerciseSnapshot>.from(source)
      ..sort((a, b) => b.estimatedVolume.compareTo(a.estimatedVolume));
    final compounds = sorted.where((e) => e.isCompound).toList(growable: false);
    final isolations = sorted
        .where((e) => !e.isCompound)
        .toList(growable: false);

    if (compounds.length >= 2 && isolations.isNotEmpty) {
      return [...compounds.take(2), ...isolations.take(1)];
    }
    if (compounds.length == 1 && isolations.length >= 2) {
      return [compounds.first, ...isolations.take(2)];
    }
    if (compounds.isNotEmpty && isolations.isEmpty) {
      return compounds.take(3).toList(growable: false);
    }
    if (isolations.isNotEmpty && compounds.isEmpty) {
      return isolations.take(3).toList(growable: false);
    }

    final mixed = <_ExerciseSnapshot>[];
    mixed.addAll(compounds.take(2));
    mixed.addAll(isolations.take(3 - mixed.length));
    return mixed.take(3).toList(growable: false);
  }

  _TargetCardData _toTarget({
    required _ExerciseSnapshot exercise,
    required BrutlUser user,
    required double mappedWeight,
    required dynamic mappedReps,
  }) {
    final parsedRange = _parseBaseRange(exercise.baseRangeString);
    final minLimit = parsedRange.min;
    final maxLimit = parsedRange.max;

    final lastTopRep = _ExerciseSnapshot.parseRepValues(mappedReps);
    final lastWeight = mappedWeight < 0 ? 0.0 : mappedWeight;
    final repsRaw = mappedReps?.toString() ?? '';

    final weightUnit = exercise.weightUnit.trim().isEmpty
        ? user.weightUnit
        : exercise.weightUnit;
    final normalizedUnit = weightUnit.trim().toLowerCase();
    final type = exercise.categoryType.trim().toLowerCase();

    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final currentDayName = dayNames[(DateTime.now().weekday - 1) % 7];

    // THE BODYWEIGHT BUG FIX: We only check if lastTopRep <= 0.
    if (lastTopRep <= 0) {
      return _TargetCardData(
        name: exercise.name,
        isCompound: exercise.isCompound,
        lastWeight: 0,
        lastReps: 0,
        lastRepsRaw: repsRaw,
        targetWeight: 0,
        targetReps: '$minLimit-$maxLimit',
        weightUnit: weightUnit,
        actionLabel: 'First Session',
        aiPayload: _toAiExercisePayload(exercise),
        isFirstSession: true,
        lastWeekDisplay: 'Nothing logged last $currentDayName.',
        targetDisplay:
            'Start your first session! Target: $minLimit-$maxLimit reps.',
      );
    }

    final displayLastRepsRaw = repsRaw.isNotEmpty ? repsRaw : '$lastTopRep';

    double targetWeight;
    String targetReps;
    String actionLabel;

    if (lastTopRep < maxLimit) {
      targetWeight = lastWeight;
      final minRep = lastTopRep + 1;
      final maxRep = math.min(lastTopRep + 2, maxLimit);
      targetReps = minRep == maxRep ? '$minRep' : '$minRep-$maxRep';
      actionLabel = 'Increase Reps';
    } else {
      if (normalizedUnit == 'plates') {
        targetWeight = lastWeight + 1;
      } else if (type.contains('compound')) {
        targetWeight = lastWeight + 5.0;
      } else {
        targetWeight = lastWeight + 2.5;
      }
      targetReps = '$minLimit-${minLimit + 1}';
      actionLabel = 'Increase Weight';
    }

    // UI POLISH: Clean format for 0kg (Bodyweight) exercises
    final lastWeekDisplayString = lastWeight > 0
        ? 'Last Week: ${_formatWeight(lastWeight)}$weightUnit x $displayLastRepsRaw'
        : 'Last Week: Bodyweight x $displayLastRepsRaw';

    final targetDisplayString = targetWeight > 0
        ? 'Target Today: ${_formatWeight(targetWeight)}$weightUnit x $targetReps 🎯'
        : 'Target Today: Bodyweight x $targetReps 🎯';

    return _TargetCardData(
      name: exercise.name,
      isCompound: exercise.isCompound,
      lastWeight: lastWeight,
      lastReps: lastTopRep,
      lastRepsRaw: displayLastRepsRaw,
      targetWeight: targetWeight,
      targetReps: targetReps,
      weightUnit: weightUnit,
      actionLabel: actionLabel,
      aiPayload: _toAiExercisePayload(exercise),
      isFirstSession: false,
      lastWeekDisplay: lastWeekDisplayString,
      targetDisplay: targetDisplayString,
    );
  }

  Map<String, dynamic> _toAiExercisePayload(_ExerciseSnapshot exercise) {
    final normalizedWeight = exercise.weight % 1 == 0
        ? exercise.weight.toStringAsFixed(0)
        : exercise.weight.toStringAsFixed(1);
    final stableId =
        'progression_${exercise.name.hashCode}_${exercise.sets}_${exercise.topSetReps}_${normalizedWeight.hashCode}';
    final model = brutl.ExerciseModel(
      id: stableId,
      name: exercise.name,
      sets: exercise.sets,
      reps: '${exercise.topSetReps}',
      weight: normalizedWeight,
      categoryType: exercise.isCompound ? 'compound' : 'isolation',
      weightUnit: exercise.weightUnit,
      isSynced: true,
      splitName: _progressionSplitName,
    );
    return model.toJson();
  }

  static bool _isRestName(String input) {
    final normalized = input.trim().toLowerCase();
    return normalized.isEmpty || normalized.contains('rest');
  }

  static String _formatWeight(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  static _BaseRange _parseBaseRange(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _BaseRange(min: 8, max: 12);
    }
    final parts = raw.trim().split('-');
    if (parts.length == 2) {
      final lo = int.tryParse(parts[0].trim());
      final hi = int.tryParse(parts[1].trim());
      if (lo != null && hi != null && hi >= lo) {
        return _BaseRange(min: lo, max: hi);
      }
    }
    final single = int.tryParse(raw.trim());
    if (single != null && single > 0) {
      return _BaseRange(min: single, max: single + 2);
    }
    return const _BaseRange(min: 8, max: 12);
  }
}

class _BaseRange {
  const _BaseRange({required this.min, required this.max});
  final int min;
  final int max;
}

class _ProgressionPayload {
  const _ProgressionPayload({required this.targets})
    : isRecovery = false,
      recoveryReason = null,
      isEmptyState = false,
      emptyStateDayName = null;

  const _ProgressionPayload.recovery(this.recoveryReason)
    : targets = const <_TargetCardData>[],
      isRecovery = true,
      isEmptyState = false,
      emptyStateDayName = null;

  const _ProgressionPayload.emptyState(this.emptyStateDayName)
    : targets = const <_TargetCardData>[],
      isRecovery = false,
      recoveryReason = null,
      isEmptyState = true;

  final List<_TargetCardData> targets;
  final bool isRecovery;
  final String? recoveryReason;
  final bool isEmptyState;
  final String? emptyStateDayName;
}

class _TargetCardData {
  const _TargetCardData({
    required this.name,
    required this.isCompound,
    required this.lastWeight,
    required this.lastReps,
    this.lastRepsRaw = '',
    required this.targetWeight,
    required this.targetReps,
    required this.weightUnit,
    required this.actionLabel,
    required this.aiPayload,
    required this.isFirstSession,
    required this.lastWeekDisplay,
    required this.targetDisplay,
  });

  final String name;
  final bool isCompound;
  final double lastWeight;
  final int lastReps;
  final String lastRepsRaw;
  final double targetWeight;
  final String targetReps;
  final String weightUnit;
  final String actionLabel;
  final Map<String, dynamic> aiPayload;
  final bool isFirstSession;
  final String lastWeekDisplay;
  final String targetDisplay;
}

class _ExerciseSnapshot {
  const _ExerciseSnapshot({
    required this.name,
    required this.isCompound,
    required this.sets,
    required this.weight,
    required this.weightUnit,
    required this.categoryType,
    required this.topSetReps,
    required this.repsRaw,
    required this.estimatedVolume,
    this.baseRangeString,
  });

  factory _ExerciseSnapshot.fromMap(Map<String, dynamic> map) {
    final topSetReps = parseRepValues(map['reps']);
    final repsRaw = map['reps']?.toString() ?? '';
    final weight = _parseWeight(map['weight'] ?? map['weightDisplay']);
    final sets = _parseInt(map['sets'], fallback: 1);
    final estimatedVolume =
        weight * math.max(1, topSetReps) * math.max(1, sets);

    final categoryRaw =
        (map['categoryType'] ?? map['category_type'] ?? map['type'] ?? '')
            .toString();
    final isCompoundFlag = map['isCompound'];
    final isCompound = isCompoundFlag is bool
        ? isCompoundFlag
        : categoryRaw.trim().toLowerCase().contains('compound');
    final categoryType = categoryRaw.trim().isNotEmpty
        ? categoryRaw.trim()
        : (isCompound ? 'compound' : 'isolation');

    final baseRangeRaw = map['baseRange'] ?? map['base_range'];
    final baseRangeString = baseRangeRaw?.toString().trim().isNotEmpty == true
        ? baseRangeRaw.toString().trim()
        : null;

    return _ExerciseSnapshot(
      name: (map['name'] ?? 'Exercise').toString(),
      isCompound: isCompound,
      sets: sets,
      weight: weight,
      weightUnit:
          (map['weightUnit'] ?? map['weight_unit'] ?? map['unit'] ?? 'Kg')
              .toString(),
      categoryType: categoryType,
      topSetReps: topSetReps,
      repsRaw: repsRaw,
      estimatedVolume: estimatedVolume,
      baseRangeString: baseRangeString,
    );
  }

  final String name;
  final bool isCompound;
  final int sets;
  final double weight;
  final String weightUnit;
  final String categoryType;
  final int topSetReps;
  final String repsRaw;
  final double estimatedVolume;
  final String? baseRangeString;

  static int parseRepValues(dynamic rawReps) {
    if (rawReps == null) return 0;
    if (rawReps is num) return rawReps.toInt();

    if (rawReps is List) {
      final listParsed = rawReps
          .map((e) => int.tryParse(e.toString().trim()) ?? 0)
          .where((e) => e > 0)
          .toList(growable: false);
      return listParsed.isNotEmpty ? listParsed.reduce(math.max) : 0;
    }

    final value = rawReps.toString().trim();
    if (value.isEmpty) return 0;

    final commaParts = value.split(',');
    if (commaParts.length > 1) {
      final commaParsed = commaParts
          .map((e) => int.tryParse(e.trim()) ?? 0)
          .where((e) => e > 0)
          .toList(growable: false);
      if (commaParsed.isNotEmpty) {
        return commaParsed.reduce(math.max);
      }
    }

    final allInts = RegExp(r'\d+')
        .allMatches(value)
        .map((m) => int.tryParse(m.group(0) ?? '') ?? 0)
        .where((e) => e > 0)
        .toList(growable: false);
    return allInts.isNotEmpty ? allInts.reduce(math.max) : 0;
  }

  static double _parseWeight(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return 0;
    final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  static int _parseInt(dynamic raw, {required int fallback}) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.item});

  final _TargetCardData item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131313),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async => HapticFeedback.lightImpact(),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isCompound
                  ? const Color(0x66FF3D00)
                  : const Color(0x6639A0FF),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.isCompound
                          ? const Color(0x22FF3D00)
                          : const Color(0x2239A0FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: item.isCompound
                            ? const Color(0x66FF3D00)
                            : const Color(0x6639A0FF),
                      ),
                    ),
                    child: Text(
                      item.isCompound ? 'Compound' : 'Isolation',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.lastWeekDisplay,
                style: const TextStyle(
                  color: Color(0xFF8B8B8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.targetDisplay,
                style: const TextStyle(
                  color: Color(0xFFFF3D00),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.actionLabel,
                style: const TextStyle(
                  color: Color(0xFFBDBDBD),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await HapticFeedback.lightImpact();
                    if (!context.mounted) return;
                    final sets = item.aiPayload['sets']?.toString() ?? '';
                    final targetSets = sets.isNotEmpty ? sets : '1';
                    final draft = item.isFirstSession
                        ? 'Coach, help me with my first session for: '
                              '${item.name} — ${item.targetReps} reps'
                        : 'Coach, adjust this target for today: '
                              '${item.name} - ${targetSets}x${item.targetReps}'
                              ' @ ${_fmtWeight(item.targetWeight)}${item.weightUnit}';
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AiCoachChatScreen(
                          initialDraft: draft,
                          initialAttachment: AiCoachAttachment(
                            type: 'workout',
                            data: item.aiPayload,
                          ),
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3D00),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.smart_toy_rounded, size: 16),
                  label: const Text(
                    'Share to AI',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtWeight(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toString();
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.dayName});
  final String dayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0x22FF3D00),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFFFF3D00),
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No exercises logged last $dayName',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Start your first session to unlock\nprogressive overload tracking!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8B8B8B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3D00), Color(0xFFFF6D00)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Go to Workout →',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryProtocol extends StatelessWidget {
  const _RecoveryProtocol({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _RecoveryCard(
          title: 'Mobility',
          subtitle:
              '10 minutes of dynamic stretching to improve tissue quality.',
          icon: Icons.accessibility_new_rounded,
        ),
        SizedBox(height: 12),
        _RecoveryCard(
          title: 'Nutrition',
          subtitle:
              'Hit your protein target even on rest days to drive recovery.',
          icon: Icons.restaurant_menu_rounded,
        ),
        SizedBox(height: 12),
        _RecoveryCard(
          title: 'Readiness',
          subtitle:
              'Log sleep score or muscle soreness before tomorrow\'s session.',
          icon: Icons.bedtime_rounded,
        ),
      ],
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151515),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async => HapticFeedback.lightImpact(),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x22FF3D00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFFF3D00), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9A9A9A),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressionSkeleton extends StatefulWidget {
  const _ProgressionSkeleton();

  @override
  State<_ProgressionSkeleton> createState() => _ProgressionSkeletonState();
}

class _ProgressionSkeletonState extends State<_ProgressionSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.25 + (_controller.value * 0.45);
        return Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: pulse,
                child: Container(
                  height: 126,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
