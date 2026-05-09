import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/brutl_models.dart';
import '../../providers/workout_provider.dart';

class ShareWorkoutScreen extends StatefulWidget {
  const ShareWorkoutScreen({super.key});

  @override
  State<ShareWorkoutScreen> createState() => _ShareWorkoutScreenState();
}

class _ShareWorkoutScreenState extends State<ShareWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _shareWeek(int weekNumber, List<ProgramDayModel> weekDays) {
    final allExercises = <Map<String, dynamic>>[];
    final dayNames = <String>[];
    for (final day in weekDays) {
      if (day.splitName.toLowerCase() == 'rest') continue;
      dayNames.add(day.splitName);
      for (final ex in day.exercises) {
        allExercises.add({
          'exerciseName': ex.name,
          'sets': ex.sets,
          'reps': ex.reps,
          'weight': ex.weightDisplay,
          'day': day.splitName,
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

  void _shareDay(String dayName, List<ExerciseModel> exercises) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'shareScope': 'day',
      'title': dayName,
      'exercises': exercises
          .map((ex) => {
                'exerciseName': ex.name,
                'sets': ex.sets,
                'reps': ex.reps,
                'weight': ex.weightDisplay,
              })
          .toList(),
    });
  }

  void _shareExercise(ExerciseModel exercise) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'shareScope': 'exercise',
      'title': exercise.name,
      'exercises': [
        {
          'exerciseName': exercise.name,
          'sets': exercise.sets,
          'reps': exercise.reps,
          'weight': exercise.weightDisplay,
        }
      ],
    });
  }

  void _showExercisePicker(String dayName, List<ExerciseModel> exercises) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: exercises.length,
                separatorBuilder: (_, __) =>
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

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final programDays = provider.programDays;
        final hasData = programDays.any((d) => d.exercises.isNotEmpty);

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
              labelStyle:
                  AppTextStyles.labelLarge(color: AppColors.accentPrimary),
              unselectedLabelStyle:
                  AppTextStyles.labelLarge(color: AppColors.textTertiary),
              tabs: const [
                Tab(text: 'WEEK'),
                Tab(text: 'DAY'),
                Tab(text: 'EXERCISE'),
              ],
            ),
          ),
          body: !hasData
              ? Center(
                  child: Text(
                    'No exercises found.\nAdd exercises from the workout screen first.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _WeekTabContent(
                      programDays: programDays,
                      onShare: _shareWeek,
                    ),
                    _DayTabContent(
                      programDays: programDays,
                      onShare: _shareDay,
                    ),
                    _ExerciseTabContent(
                      programDays: programDays,
                      onShowPicker: _showExercisePicker,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// =============================================================================
// Week tab
// =============================================================================

class _WeekTabContent extends StatelessWidget {
  const _WeekTabContent({
    required this.programDays,
    required this.onShare,
  });

  final List<ProgramDayModel> programDays;
  final void Function(int weekNumber, List<ProgramDayModel> weekDays) onShare;

  @override
  Widget build(BuildContext context) {
    final weeks = programDays.map((d) => d.weekNumber).toSet().toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: weeks.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final week = weeks[i];
        final weekDays = programDays
            .where(
              (d) =>
                  d.weekNumber == week &&
                  d.splitName.toLowerCase() != 'rest',
            )
            .toList()
          ..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
        final exerciseCount =
            weekDays.fold(0, (sum, d) => sum + d.exercises.length);

        return _ScopeCard(
          icon: Icons.calendar_month,
          title: 'Week $week',
          subtitle: '${weekDays.length} days · $exerciseCount exercises',
          isHighlighted: true,
          onTap: () => onShare(week, weekDays),
        );
      },
    );
  }
}

// =============================================================================
// Day tab
// =============================================================================

class _DayTabContent extends StatelessWidget {
  const _DayTabContent({
    required this.programDays,
    required this.onShare,
  });

  final List<ProgramDayModel> programDays;
  final void Function(String dayName, List<ExerciseModel> exercises) onShare;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final uniqueDays = <ProgramDayModel>[];
    for (final d in programDays) {
      if (d.splitName.toLowerCase() == 'rest') continue;
      if (seen.add(d.splitName)) uniqueDays.add(d);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: uniqueDays.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final day = uniqueDays[i];
        return _ScopeCard(
          icon: Icons.fitness_center_rounded,
          title: day.splitName,
          subtitle:
              '${day.exercises.length} exercise${day.exercises.length == 1 ? '' : 's'}',
          onTap: () => onShare(day.splitName, day.exercises),
        );
      },
    );
  }
}

// =============================================================================
// Exercise tab
// =============================================================================

class _ExerciseTabContent extends StatelessWidget {
  const _ExerciseTabContent({
    required this.programDays,
    required this.onShowPicker,
  });

  final List<ProgramDayModel> programDays;
  final void Function(
    String dayName,
    List<ExerciseModel> exercises,
  ) onShowPicker;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final uniqueDays = <ProgramDayModel>[];
    for (final d in programDays) {
      if (d.splitName.toLowerCase() == 'rest') continue;
      if (d.exercises.isEmpty) continue;
      if (seen.add(d.splitName)) uniqueDays.add(d);
    }

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
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final day = uniqueDays[i];
        return _ScopeCard(
          icon: Icons.sports_gymnastics,
          title: day.splitName,
          subtitle: 'Tap to pick a specific exercise',
          showChevron: true,
          onTap: () => onShowPicker(day.splitName, day.exercises),
        );
      },
    );
  }
}

// =============================================================================
// Shared scope card
// =============================================================================

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
                    style:
                        AppTextStyles.labelSmall(color: AppColors.textTertiary),
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
  final ExerciseModel exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  Text(exercise.name,
                      style: AppTextStyles.headingSmall()),
                  Text(
                    '${exercise.sets} sets × ${exercise.reps} reps • ${exercise.weightDisplay} ${exercise.weightUnit}',
                    style: AppTextStyles.labelSmall(
                        color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.send_rounded,
                color: AppColors.accentPrimary, size: 16),
          ],
        ),
      ),
    );
  }
}
