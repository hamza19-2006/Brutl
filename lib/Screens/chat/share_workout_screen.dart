import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/workout_provider.dart';

class ShareWorkoutScreen extends StatefulWidget {
  const ShareWorkoutScreen({super.key});

  @override
  State<ShareWorkoutScreen> createState() => _ShareWorkoutScreenState();
}

class _ShareWorkoutScreenState extends State<ShareWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // All loaded data: weekNumber → dayIndex → {dayName, exercises}
  Map<int, List<_DayData>> _weekMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromFirestore());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFromFirestore() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final provider = context.read<WorkoutProvider>();
    final totalWeeks = provider.totalProgramWeeks;
    final dayNames = provider.customSplitDays;
    final totalDays = dayNames.length;

    final db = FirebaseFirestore.instance;
    final result = <int, List<_DayData>>{};

    for (var week = 1; week <= totalWeeks; week++) {
      final weekId = 'week_$week';
      final days = <_DayData>[];

      for (var d = 0; d < totalDays; d++) {
        final dayId = 'day_${d + 1}';
        final dayName = dayNames[d];

        try {
          final snap = await db
              .collection('users')
              .doc(uid)
              .collection('weeks')
              .doc(weekId)
              .collection('days')
              .doc(dayId)
              .get();

          final rawExercises =
              ((snap.data()?['exercises']) as List<dynamic>?) ?? const [];
          final exercises = rawExercises
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          days.add(
            _DayData(
              weekId: weekId,
              dayId: dayId,
              dayName: dayName,
              dayIndex: d,
              exercises: exercises,
            ),
          );
        } catch (_) {
          days.add(
            _DayData(
              weekId: weekId,
              dayId: dayId,
              dayName: dayName,
              dayIndex: d,
              exercises: const [],
            ),
          );
        }
      }

      result[week] = days;
    }

    if (mounted) {
      setState(() {
        _weekMap = result;
        _isLoading = false;
      });
    }
  }

  bool get _hasAnyExercise =>
      _weekMap.values.any((days) => days.any((d) => d.exercises.isNotEmpty));

  // ── navigation helpers ────────────────────────────────────────────────────

  void _shareWeek(int weekNumber, List<_DayData> weekDays) {
    final allExercises = <Map<String, dynamic>>[];
    final dayNames = <String>[];

    for (final day in weekDays) {
      if (day.dayName.toLowerCase() == 'rest') continue;
      dayNames.add(day.dayName);
      for (final ex in day.exercises) {
        allExercises.add({
          'exerciseName': ex['name'] ?? '',
          'sets': ex['sets'],
          'reps': ex['reps'],
          'weight': ex['weight'] ?? '',
          'day': day.dayName,
        });
      }
    }

    Navigator.pop<Map<String, dynamic>>(context, {
      'shareScope': 'week',
      'title': 'Week $weekNumber',
      'weekNumber': weekNumber,
      'days': dayNames,
      'exercises': allExercises,
    });
  }

  void _shareDay(String dayName, List<Map<String, dynamic>> exercises) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'shareScope': 'day',
      'title': dayName,
      'exercises': exercises
          .map(
            (ex) => {
              'exerciseName': ex['name'] ?? '',
              'sets': ex['sets'],
              'reps': ex['reps'],
              'weight': ex['weight'] ?? '',
            },
          )
          .toList(),
    });
  }

  void _shareExercise(Map<String, dynamic> exercise) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'shareScope': 'exercise',
      'title': exercise['name'] ?? 'Exercise',
      'exercises': [
        {
          'exerciseName': exercise['name'] ?? '',
          'sets': exercise['sets'],
          'reps': exercise['reps'],
          'weight': exercise['weight'] ?? '',
        },
      ],
    });
  }

  void _showExercisePicker(
    String dayName,
    List<Map<String, dynamic>> exercises,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLarge),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(dayName, style: AppTextStyles.headingLarge()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareDay(dayName, exercises);
                    },
                    child: Text(
                      'Share Day',
                      style: AppTextStyles.headingSmall(
                        color: AppColors.accentPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: exercises.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, i) {
                  final ex = exercises[i];
                  return _ExerciseTile(
                    exercise: ex,
                    onTap: () {
                      Navigator.pop(ctx);
                      _shareExercise(ex);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Share Workout', style: AppTextStyles.headingLarge()),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentPrimary,
          indicatorWeight: 2,
          labelColor: AppColors.accentPrimary,
          unselectedLabelColor: AppColors.textTertiary,
          labelStyle: AppTextStyles.labelLarge(color: AppColors.accentPrimary),
          unselectedLabelStyle: AppTextStyles.labelLarge(
            color: AppColors.textTertiary,
          ),
          tabs: const [
            Tab(text: 'WEEK'),
            Tab(text: 'DAY'),
            Tab(text: 'EXERCISE'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            )
          : !_hasAnyExercise
          ? Center(
              child: Text(
                'No exercises found.\nAdd exercises from the workout screen first.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _WeekTab(weekMap: _weekMap, onShare: _shareWeek),
                _DayTab(weekMap: _weekMap, onShare: _shareDay),
                _ExerciseTab(
                  weekMap: _weekMap,
                  onShowPicker: _showExercisePicker,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data holder
// ---------------------------------------------------------------------------

class _DayData {
  const _DayData({
    required this.weekId,
    required this.dayId,
    required this.dayName,
    required this.dayIndex,
    required this.exercises,
  });

  final String weekId;
  final String dayId;
  final String dayName;
  final int dayIndex;
  final List<Map<String, dynamic>> exercises;
}

// ---------------------------------------------------------------------------
// Week tab
// ---------------------------------------------------------------------------

class _WeekTab extends StatelessWidget {
  const _WeekTab({required this.weekMap, required this.onShare});

  final Map<int, List<_DayData>> weekMap;
  final void Function(int week, List<_DayData> days) onShare;

  @override
  Widget build(BuildContext context) {
    final weeks = weekMap.keys.toList()..sort();
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: weeks.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final week = weeks[i];
        final days = weekMap[week] ?? [];
        final activeDays = days.where(
          (d) => d.dayName.toLowerCase() != 'rest' && d.exercises.isNotEmpty,
        );
        final exerciseCount = activeDays.fold(
          0,
          (total, day) => total + day.exercises.length,
        );

        return _ScopeCard(
          icon: Icons.calendar_month,
          title: 'Week $week',
          subtitle: '${activeDays.length} days · $exerciseCount exercises',
          isHighlighted: true,
          onTap: () => onShare(week, days),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day tab — deduplicated by name, uses the week with the most exercises
// ---------------------------------------------------------------------------

class _DayTab extends StatelessWidget {
  const _DayTab({required this.weekMap, required this.onShare});

  final Map<int, List<_DayData>> weekMap;
  final void Function(String dayName, List<Map<String, dynamic>> exercises)
  onShare;

  @override
  Widget build(BuildContext context) {
    // Build a map: normalised dayName → best _DayData (most exercises)
    final bestByName = <String, _DayData>{};
    for (final days in weekMap.values) {
      for (final day in days) {
        if (day.dayName.toLowerCase() == 'rest') continue;
        final key = day.dayName.trim().toLowerCase();
        final existing = bestByName[key];
        if (existing == null ||
            day.exercises.length > existing.exercises.length) {
          bestByName[key] = day;
        }
      }
    }

    final uniqueDays = bestByName.values.toList();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: uniqueDays.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final day = uniqueDays[i];
        return _ScopeCard(
          icon: Icons.fitness_center_rounded,
          title: day.dayName,
          subtitle:
              '${day.exercises.length} exercise${day.exercises.length == 1 ? '' : 's'}',
          onTap: () => onShare(day.dayName, day.exercises),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise tab — groups by day, shows picker
// ---------------------------------------------------------------------------

class _ExerciseTab extends StatelessWidget {
  const _ExerciseTab({required this.weekMap, required this.onShowPicker});

  final Map<int, List<_DayData>> weekMap;
  final void Function(String dayName, List<Map<String, dynamic>> exercises)
  onShowPicker;

  @override
  Widget build(BuildContext context) {
    final bestByName = <String, _DayData>{};
    for (final days in weekMap.values) {
      for (final day in days) {
        if (day.dayName.toLowerCase() == 'rest') continue;
        if (day.exercises.isEmpty) continue;
        final key = day.dayName.trim().toLowerCase();
        final existing = bestByName[key];
        if (existing == null ||
            day.exercises.length > existing.exercises.length) {
          bestByName[key] = day;
        }
      }
    }

    final uniqueDays = bestByName.values.toList();

    if (uniqueDays.isEmpty) {
      return Center(
        child: Text(
          'No exercises found.',
          style: AppTextStyles.bodyMedium(color: AppColors.textTertiary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: uniqueDays.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final day = uniqueDays[i];
        return _ScopeCard(
          icon: Icons.sports_gymnastics,
          title: day.dayName,
          subtitle: 'Tap to pick a specific exercise',
          showChevron: true,
          onTap: () => onShowPicker(day.dayName, day.exercises),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isHighlighted = false,
    this.showChevron = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isHighlighted;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.accentGlow
              : AppColors.backgroundTertiary,
          border: Border.all(
            color: isHighlighted
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isHighlighted
                  ? AppColors.accentPrimary
                  : AppColors.textTertiary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.headingSmall()),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onTap});

  final Map<String, dynamic> exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = exercise['name']?.toString() ?? 'Exercise';
    final sets = exercise['sets']?.toString() ?? '—';
    final reps = exercise['reps']?.toString() ?? '—';
    final weight = exercise['weight']?.toString() ?? '';
    final unit = exercise['weightUnit']?.toString() ?? 'kg';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundTertiary,
          border: Border.all(color: AppColors.borderDefault),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.headingSmall()),
                  Text(
                    '$sets sets × $reps reps${weight.isNotEmpty ? ' • $weight $unit' : ''}',
                    style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.send_rounded,
              color: AppColors.accentPrimary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
