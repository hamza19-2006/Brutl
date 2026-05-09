import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/brutl_models.dart';

class ShareWorkoutScreen extends StatefulWidget {
  const ShareWorkoutScreen({super.key});

  @override
  State<ShareWorkoutScreen> createState() => _ShareWorkoutScreenState();
}

class _ShareWorkoutScreenState extends State<ShareWorkoutScreen> {
  Map<String, List<ExerciseModel>> _splitExercises = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final box = Hive.box<String>('exercises');
      final grouped = <String, List<ExerciseModel>>{};

      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) continue;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final exercise = ExerciseModel.fromJson(json);
        final dayName =
            exercise.splitName.isNotEmpty ? exercise.splitName : 'Unassigned';
        grouped.putIfAbsent(dayName, () => []).add(exercise);
      }

      if (mounted) {
        setState(() {
          _splitExercises = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareWholeWeek() {
    final allExercises = <Map<String, dynamic>>[];
    for (final entry in _splitExercises.entries) {
      for (final ex in entry.value) {
        allExercises.add({
          'exerciseName': ex.name,
          'sets': ex.sets,
          'reps': ex.reps,
          'weight': ex.weightDisplay,
          'day': entry.key,
        });
      }
    }
    Navigator.pop<Map<String, dynamic>>(context, {
      'name': 'Full Week',
      'exercises': allExercises,
    });
  }

  void _shareDay(String dayName, List<ExerciseModel> exercises) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'name': dayName,
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
      'name': exercise.name,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Share Workout', style: AppTextStyles.headingLarge()),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accentPrimary))
          : _splitExercises.isEmpty
              ? Center(
                  child: Text('No exercises found',
                      style: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary)),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Whole Week
                    _DayCard(
                      name: 'Whole Week',
                      exerciseCount:
                          _splitExercises.values.fold(0, (s, l) => s + l.length),
                      isHighlighted: true,
                      onTap: _shareWholeWeek,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('By Day',
                        style: AppTextStyles.headingSmall(
                            color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final entry in _splitExercises.entries) ...[
                      _DayCard(
                        name: entry.key,
                        exerciseCount: entry.value.length,
                        onTap: () => _showDayDetail(entry.key, entry.value),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
    );
  }

  void _showDayDetail(String dayName, List<ExerciseModel> exercises) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.borderRadiusLarge)),
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
                    child: Text(dayName,
                        style: AppTextStyles.headingLarge()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareDay(dayName, exercises);
                    },
                    child: Text('Share All',
                        style: AppTextStyles.headingSmall(
                            color: AppColors.accentPrimary)),
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
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.name,
    required this.exerciseCount,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String name;
  final int exerciseCount;
  final VoidCallback onTap;
  final bool isHighlighted;

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
          borderRadius:
              BorderRadius.circular(AppSpacing.borderRadiusMedium),
        ),
        child: Row(
          children: [
            Icon(Icons.fitness_center_rounded,
                color: isHighlighted
                    ? AppColors.accentPrimary
                    : AppColors.textTertiary,
                size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.headingSmall()),
                  Text('$exerciseCount exercises',
                      style: AppTextStyles.labelSmall(
                          color: AppColors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
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
