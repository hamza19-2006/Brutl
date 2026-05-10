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

  @override
  void initState() {
    super.initState();
    _payloadFuture = _buildPayload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProgressionPayload>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ProgressionSkeleton();
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isRecovery) {
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const _ProgressionPayload.recovery('No signed-in user');
    }

    final workoutProvider = context.read<WorkoutProvider>();
    final userModel = context.read<BrutlUserProvider>().user;
    final todayIndex = DateTime.now().weekday - 1;
    final splitDays = workoutProvider.activeSplitDays;
    final inBounds = todayIndex >= 0 && todayIndex < splitDays.length;
    final todayName = inBounds ? splitDays[todayIndex] : '';
    final isRestDay = !inBounds || _isRestName(todayName);
    if (isRestDay) {
      return const _ProgressionPayload.recovery('Split says rest day');
    }

    final currentWeek = workoutProvider.selectedWeek;
    final previousWeek = currentWeek - 1;
    if (previousWeek <= 0) {
      return const _ProgressionPayload.recovery('No previous week data');
    }

    final previousDayRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc('week_$previousWeek')
        .collection('days')
        .doc('day_${todayIndex + 1}');

    final previousDaySnap = await previousDayRef.get();
    final rawExercises =
        (previousDaySnap.data()?['exercises'] as List<dynamic>?) ??
        const <dynamic>[];
    if (rawExercises.isEmpty) {
      return const _ProgressionPayload.recovery(
        'No exercises on previous week day',
      );
    }

    final parsed = rawExercises
        .whereType<Map>()
        .map((raw) => _ExerciseSnapshot.fromMap(Map<String, dynamic>.from(raw)))
        .where((e) => e.name.trim().isNotEmpty)
        .toList(growable: false);

    if (parsed.isEmpty) {
      return const _ProgressionPayload.recovery('No parseable exercise data');
    }

    final selected = _selectExercises(parsed);
    if (selected.isEmpty) {
      return const _ProgressionPayload.recovery('No eligible exercises');
    }

    final targets = selected
        .map((e) => _toTarget(exercise: e, user: userModel))
        .toList(growable: false);

    if (targets.isEmpty) {
      return const _ProgressionPayload.recovery('No target calculations');
    }

    return _ProgressionPayload(targets: targets);
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
    final minRep = exercise.isCompound
        ? user.compoundRepMin
        : user.isolationRepMin;
    final maxRep = exercise.isCompound
        ? user.compoundRepMax
        : user.isolationRepMax;
    final safeMin = minRep <= 0 ? 1 : minRep;
    final safeMax = maxRep < safeMin ? safeMin : maxRep;
    final lastTopReps = exercise.topSetReps > 0 ? exercise.topSetReps : safeMin;
    final unit = exercise.weightUnit.trim().isEmpty
        ? user.weightUnit
        : exercise.weightUnit;
    final increment = _isLbs(unit) ? 5.0 : 2.5;

    if (lastTopReps >= safeMax) {
      final nextWeight = _roundToIncrement(
        exercise.weight + increment,
        increment,
      );
      return _TargetCardData(
        name: exercise.name,
        isCompound: exercise.isCompound,
        lastWeight: exercise.weight,
        lastReps: lastTopReps,
        targetWeight: nextWeight,
        targetReps: safeMin,
        weightUnit: unit,
        actionLabel: 'Increase Weight',
        aiPayload: _toAiExercisePayload(exercise),
      );
    }

    final room = safeMax - lastTopReps;
    final bump = room >= 2 ? 2 : 1;
    final targetReps = (lastTopReps + bump).clamp(safeMin, safeMax);

    return _TargetCardData(
      name: exercise.name,
      isCompound: exercise.isCompound,
      lastWeight: exercise.weight,
      lastReps: lastTopReps,
      targetWeight: exercise.weight,
      targetReps: targetReps,
      weightUnit: unit,
      actionLabel: 'Increase Reps',
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

  static bool _isLbs(String unit) => unit.trim().toLowerCase().contains('lb');

  static double _roundToIncrement(double value, double increment) {
    if (increment <= 0) return value;
    final scaled = (value / increment).round();
    return scaled * increment;
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
    required this.estimatedVolume,
  });

  factory _ExerciseSnapshot.fromMap(Map<String, dynamic> map) {
    final reps = _parseRepValues(map['reps']);
    final topSetReps = reps.isEmpty ? 0 : reps.reduce(math.max);
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
      estimatedVolume: estimatedVolume,
    );
  }

  final String name;
  final bool isCompound;
  final int sets;
  final double weight;
  final String weightUnit;
  final int topSetReps;
  final double estimatedVolume;

  static List<int> _parseRepValues(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => _parseInt(e, fallback: 0))
          .where((v) => v > 0)
          .toList(growable: false);
    }
    if (raw is num) return <int>[raw.toInt()];
    if (raw == null) return const <int>[];
    return RegExp(r'\d+')
        .allMatches(raw.toString())
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
    required this.targetWeight,
    required this.targetReps,
    required this.weightUnit,
    required this.actionLabel,
    required this.aiPayload,
  });

  final String name;
  final bool isCompound;
  final double lastWeight;
  final int lastReps;
  final double targetWeight;
  final int targetReps;
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
              Text(
                'Last Week: ${_fmtWeight(item.lastWeight)}${item.weightUnit} x ${item.lastReps}',
                style: const TextStyle(
                  color: Color(0xFF8B8B8B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Target Today: ${_fmtWeight(item.targetWeight)}${item.weightUnit} x ${item.targetReps} 🎯',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await HapticFeedback.lightImpact();
                        if (!context.mounted) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AiCoachChatScreen(
                              initialDraft:
                                  'Help me optimize progression for this exercise.',
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.smart_toy),
                      color: const Color(0xFFFF3D00),
                      tooltip: 'Share preset to AI',
                      onPressed: () async {
                        await HapticFeedback.lightImpact();
                        if (!context.mounted) return;
                        final sets = item.aiPayload['sets']?.toString() ?? '';
                        final targetSets = sets.isNotEmpty ? sets : '1';
                        final draft =
                            'Coach, adjust this target for today: ${item.name} - ${targetSets}x${item.targetReps} @ ${_fmtWeight(item.targetWeight)}${item.weightUnit}';
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
