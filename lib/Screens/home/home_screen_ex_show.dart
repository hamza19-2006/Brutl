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
    final templateFallback = uid == null || uid.isEmpty
        ? guaranteedFallback
        : (await _buildTemplateFallbackPayload(
                uid: uid,
                todayIndex: todayIndex,
                todayName: todayName,
                currentWeek: workoutProvider.selectedWeek,
                userModel: userModel,
              )) ??
              guaranteedFallback;

    if (uid == null || uid.isEmpty) {
      return templateFallback;
    }

    try {
      final currentWeek = workoutProvider.selectedWeek;
      final dayNumber = todayIndex + 1;
      final rawExercises = await _loadPreviousWeekDayExercises(
        uid: uid,
        currentWeek: currentWeek,
        dayNumber: dayNumber,
      );
      if (rawExercises.isEmpty) {
        return templateFallback;
      }

      final parsed = rawExercises
          .whereType<Map>()
          .map(
            (raw) => _ExerciseSnapshot.fromMap(Map<String, dynamic>.from(raw)),
          )
          .where((e) => e.name.trim().isNotEmpty)
          .toList(growable: false);

      if (parsed.isEmpty) {
        return templateFallback;
      }

      final selected = _selectExercises(parsed);
      if (selected.isEmpty) {
        return templateFallback;
      }

      final targets = selected
          .map((e) => _toTarget(exercise: e, user: userModel))
          .toList(growable: false);

      if (targets.isEmpty) {
        return templateFallback;
      }

      return _ProgressionPayload(targets: targets);
    } catch (_) {
      return templateFallback;
    }
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
                (raw) => _ExerciseSnapshot.fromMap(Map<String, dynamic>.from(raw)),
              )
              .toList(growable: false);
    final targets = resolvedSource
        .take(3)
        .map((e) => _toTemplateTarget(exercise: e, user: userModel))
        .toList(growable: false);
    return _ProgressionPayload(targets: targets);
  }

  Future<List<dynamic>> _loadPreviousWeekDayExercises({
    required String uid,
    required int currentWeek,
    required int dayNumber,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final candidates = <int>[];
    final seen = <int>{};

    void addCandidate(int week) {
      if (week <= 0 || seen.contains(week)) return;
      seen.add(week);
      candidates.add(week);
    }

    if (currentWeek > 1) {
      addCandidate(currentWeek - 1);
    }

    final weeksSnap = await firestore
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .get();

    final discoveredWeeks =
        weeksSnap.docs
            .map((doc) {
              final match = RegExp(r'^week_(\d+)$').firstMatch(doc.id);
              if (match == null) return null;
              return int.tryParse(match.group(1)!);
            })
            .whereType<int>()
            .toList(growable: false)
          ..sort((a, b) => b.compareTo(a));

    for (final week in discoveredWeeks) {
      if (currentWeek > 1 && week >= currentWeek) continue;
      addCandidate(week);
    }

    for (final week in candidates) {
      final daySnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('weeks')
          .doc('week_$week')
          .collection('days')
          .doc('day_$dayNumber')
          .get();

      final rawExercises =
          (daySnap.data()?['exercises'] as List<dynamic>?) ?? const <dynamic>[];
      if (rawExercises.isNotEmpty) {
        return rawExercises;
      }
    }

    return const <dynamic>[];
  }

  Future<_ProgressionPayload?> _buildTemplateFallbackPayload({
    required String uid,
    required int todayIndex,
    required String todayName,
    required int currentWeek,
    required BrutlUser userModel,
  }) async {
    try {
      final templateExercises = await _loadTemplateExercisesForToday(
        uid: uid,
        todayIndex: todayIndex,
        todayName: todayName,
        currentWeek: currentWeek,
      );
      if (templateExercises.isEmpty) return null;

      final parsed = templateExercises
          .whereType<Map>()
          .map(
            (raw) => _ExerciseSnapshot.fromMap(Map<String, dynamic>.from(raw)),
          )
          .where((e) => e.name.trim().isNotEmpty)
          .toList(growable: false);
      if (parsed.isEmpty) return null;

      final selected = _selectExercises(parsed);
      if (selected.isEmpty) return null;

      final targets = selected
          .map((e) => _toTemplateTarget(exercise: e, user: userModel))
          .toList(growable: false);
      if (targets.isEmpty) return null;

      return _ProgressionPayload(targets: targets);
    } catch (_) {
      return null;
    }
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
    final raw = (snap.data()?['exercises'] as List<dynamic>?) ?? const [];
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
              'reps': '8-12',
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
    final minRep = exercise.isCompound
        ? user.compoundRepMin
        : user.isolationRepMin;
    final maxRep = exercise.isCompound
        ? user.compoundRepMax
        : user.isolationRepMax;
    final safeMin = minRep <= 0 ? 1 : minRep;
    final safeMax = maxRep < safeMin ? safeMin : maxRep;
    final baseReps = ((safeMin + safeMax) / 2)
        .round()
        .clamp(safeMin, safeMax)
        .toInt();
    final unit = exercise.weightUnit.trim().isEmpty
        ? user.weightUnit
        : exercise.weightUnit;
    final startWeight = exercise.weight < 0 ? 0.0 : exercise.weight;

    // MODULE 2C: Emit base-range as a string (e.g. "8-12")
    final templateRepsString = safeMin == safeMax
        ? '$safeMin'
        : '$safeMin-$safeMax';

    return _TargetCardData(
      name: exercise.name,
      isCompound: exercise.isCompound,
      lastWeight: startWeight,
      lastReps: baseReps,
      targetWeight: startWeight,
      targetRepsString: templateRepsString,
      weightUnit: unit,
      actionLabel: 'Base range: $safeMin-$safeMax reps',
      aiPayload: _toAiExercisePayload(exercise),
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
  }) {
    // ── Step 2A: Variable Extraction ──────────────────────────────────────
    final minRep = exercise.isCompound
        ? user.compoundRepMin
        : user.isolationRepMin;
    final maxRep = exercise.isCompound
        ? user.compoundRepMax
        : user.isolationRepMax;
    // Base range with safe fallbacks (default 8-12 if parsing fails)
    final lowerLimit = minRep <= 0 ? 8 : minRep;
    final upperLimit = maxRep < lowerLimit ? 12 : maxRep;

    final lastTopRep = exercise.topSetReps > 0 ? exercise.topSetReps : lowerLimit;
    final lastWeight = exercise.weight;
    final weightUnit = exercise.weightUnit.trim().isEmpty
        ? user.weightUnit
        : exercise.weightUnit;
    final exerciseType = exercise.isCompound ? 'Compound' : 'Isolation';

    // Freeze the "last week" display value BEFORE calculating target
    final displayLastReps = lastTopRep;

    double newTargetWeight;
    String newTargetRepsString;
    String actionLabel;

    // ── Step 2B: Mathematical Branching Logic ─────────────────────────────
    if (lastTopRep >= upperLimit) {
      // ── BRANCH 1: UPPER LIMIT REACHED → WEIGHT PROGRESSION ────────────
      if (weightUnit.toLowerCase().contains('plate')) {
        // Plates: +1 plate
        newTargetWeight = lastWeight + 1;
      } else if (exerciseType.toLowerCase().contains('compound')) {
        // Compound: +5.0 Kg/Lbs
        newTargetWeight = lastWeight + 5.0;
      } else {
        // Isolation: +2.5 Kg/Lbs
        newTargetWeight = lastWeight + 2.5;
      }
      // Reset reps to bottom of base range
      newTargetRepsString = '$lowerLimit-${lowerLimit + 1}';
      actionLabel = 'Increase Weight';
    } else {
      // ── BRANCH 2: BELOW UPPER LIMIT → REP PROGRESSION ─────────────────
      newTargetWeight = lastWeight;
      final repTargetMin = lastTopRep + 1;
      int repTargetMax = lastTopRep + 2;
      // Crucial cap: clamp to upperLimit
      if (repTargetMax > upperLimit) repTargetMax = upperLimit;
      if (repTargetMin > upperLimit) {
        // Edge case: already at or past upper limit
        newTargetRepsString = '$upperLimit';
      } else if (repTargetMin == repTargetMax) {
        newTargetRepsString = '$repTargetMin';
      } else {
        newTargetRepsString = '$repTargetMin-$repTargetMax';
      }
      actionLabel = 'Increase Reps';
    }

    return _TargetCardData(
      name: exercise.name,
      isCompound: exercise.isCompound,
      lastWeight: lastWeight,
      lastReps: displayLastReps,
      lastRepsRaw: exercise.repsRaw,
      targetWeight: newTargetWeight,
      targetRepsString: newTargetRepsString,
      weightUnit: weightUnit,
      actionLabel: actionLabel,
      aiPayload: _toAiExercisePayload(exercise),
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

}

class _ProgressionPayload {
  const _ProgressionPayload({required this.targets})
    : isRecovery = false,
      recoveryReason = null;

  const _ProgressionPayload.recovery(this.recoveryReason)
    : targets = const <_TargetCardData>[],
      isRecovery = true;

  final List<_TargetCardData> targets;
  final bool isRecovery;
  final String? recoveryReason;
}

class _ExerciseSnapshot {
  const _ExerciseSnapshot({
    required this.name,
    required this.isCompound,
    required this.sets,
    required this.weight,
    required this.weightUnit,
    required this.topSetReps,
    required this.repsRaw,
    required this.estimatedVolume,
  });

  factory _ExerciseSnapshot.fromMap(Map<String, dynamic> map) {
    // BUG 1 FIX: Explicit comma-split parsing for rep strings
    final reps = _parseRepValues(map['reps']);
    final topSetReps = reps.isEmpty ? 0 : reps.reduce(math.max);
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

    return _ExerciseSnapshot(
      name: (map['name'] ?? 'Exercise').toString(),
      isCompound: isCompound,
      sets: sets,
      weight: weight,
      weightUnit:
          (map['weightUnit'] ?? map['weight_unit'] ?? map['unit'] ?? 'Kg')
              .toString(),
      topSetReps: topSetReps,
      repsRaw: repsRaw,
      estimatedVolume: estimatedVolume,
    );
  }

  final String name;
  final bool isCompound;
  final int sets;
  final double weight;
  final String weightUnit;
  final int topSetReps;
  /// The original raw reps string from Firestore (e.g. "6,5" or "10,8")
  final String repsRaw;
  final double estimatedVolume;

  /// BUG 1 FIX: Parse comma-separated rep strings safely.
  /// Input "6,5"  → [6, 5]  → max = 6
  /// Input "10,8" → [10, 8] → max = 10
  /// Input "8-12" → [8, 12] → max = 12  (range format)
  /// Input 10      → [10]
  static List<int> _parseRepValues(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => _parseInt(e, fallback: 0))
          .where((v) => v > 0)
          .toList(growable: false);
    }
    if (raw is num) return <int>[raw.toInt()];
    if (raw == null) return const <int>[];

    final str = raw.toString().trim();
    if (str.isEmpty) return const <int>[];

    // Primary: split by comma (handles "6,5", "10,8,7")
    if (str.contains(',')) {
      final parts = str
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .where((v) => v > 0)
          .toList(growable: false);
      if (parts.isNotEmpty) return parts;
    }

    // Fallback: extract all digit groups (handles "8-12", "8 x 12", etc.)
    return RegExp(r'\d+')
        .allMatches(str)
        .map((m) => int.tryParse(m.group(0) ?? '') ?? 0)
        .where((v) => v > 0)
        .toList(growable: false);
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

class _TargetCardData {
  const _TargetCardData({
    required this.name,
    required this.isCompound,
    required this.lastWeight,
    required this.lastReps,
    this.lastRepsRaw = '',
    required this.targetWeight,
    required this.targetRepsString,
    required this.weightUnit,
    required this.actionLabel,
    required this.aiPayload,
  });

  final String name;
  final bool isCompound;
  final double lastWeight;
  /// The extracted top rep from last week (strictly for display)
  final int lastReps;
  /// Raw rep string from Firestore for optional display (e.g. "6,5")
  final String lastRepsRaw;
  final double targetWeight;
  /// MODULE 2A: Target reps is now a String range (e.g. "7-8", "4-5", "10")
  final String targetRepsString;
  final String weightUnit;
  final String actionLabel;
  final Map<String, dynamic> aiPayload;
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
              // MODULE 3: "Last Week" shows raw reps, "Target Today" shows
              // the computed string range from the progressive overload engine.
              Text(
                'Last Week: ${_fmtWeight(item.lastWeight)}${item.weightUnit} x ${item.lastRepsRaw.isNotEmpty ? item.lastRepsRaw : '${item.lastReps}'}',
                style: const TextStyle(
                  color: Color(0xFF8B8B8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Target Today: ${_fmtWeight(item.targetWeight)}${item.weightUnit} x ${item.targetRepsString} 🎯',
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
                    final draft =
                        'Coach, adjust this target for today: ${item.name} - ${targetSets}x${item.targetRepsString} @ ${_fmtWeight(item.targetWeight)}${item.weightUnit}';
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
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _RecoveryProtocol extends StatelessWidget {
  const _RecoveryProtocol({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
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
              'Log sleep score or muscle soreness before tomorrow’s session.',
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
