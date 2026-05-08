import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/brutl_models.dart' as brutl;
import '../../../providers/workout_provider.dart';
import '../widgets/settings_widgets.dart';

class EditExercisesScreen extends StatefulWidget {
  const EditExercisesScreen({
    super.key,
    required this.dayId,
    required this.dayName,
    required this.weekIndex,
  });

  final String dayId;
  final String dayName;
  final int weekIndex;

  @override
  State<EditExercisesScreen> createState() => _EditExercisesScreenState();
}

class _EditExercisesScreenState extends State<EditExercisesScreen> {
  String _activeDayName(WorkoutProvider provider) {
    return provider.getDayForWeek(widget.weekIndex, widget.dayId)?.splitName ??
        widget.dayName;
  }

  Future<void> _showRenameDialog(brutl.ExerciseModel exercise) async {
    final controller = TextEditingController(text: exercise.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        title: Text('Rename Exercise', style: AppTextStyles.headingMedium()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              'Save',
              style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == exercise.name) return;
    if (!mounted) return;

    final workoutProvider = context.read<WorkoutProvider>();
    final dayName = _activeDayName(workoutProvider);

    unawaited(
      workoutProvider.renameExerciseOptimistic(
        widget.weekIndex,
        dayName,
        exercise.name,
        newName,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Exercise renamed to "$newName".'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showDeleteDialog(brutl.ExerciseModel exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.statusError),
        ),
        title: Text(
          'Delete Exercise',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Delete "${exercise.name}" from this day?',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.headingSmall(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final workoutProvider = context.read<WorkoutProvider>();
    final dayName = _activeDayName(workoutProvider);

    unawaited(
      workoutProvider.deleteExerciseOptimistic(
        widget.weekIndex,
        dayName,
        exercise.name,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${exercise.name}" deleted.'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        final dayName = _activeDayName(provider);
        final exercises = provider.getExercisesForWeekDay(
          widget.weekIndex,
          widget.dayId,
        );

        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          appBar: buildSettingsAppBar(context, '$dayName Exercises'),
          body: SafeArea(
            child: exercises.isEmpty
                ? Center(
                    child: Text(
                      'No exercises for this day.',
                      style: AppTextStyles.bodyMedium(),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    itemCount: exercises.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.borderRadiusMedium,
                                ),
                                border: Border.all(color: AppColors.borderDefault),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.name,
                                    style: AppTextStyles.headingSmall(),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${exercise.sets} sets · ${exercise.reps} reps',
                                    style: AppTextStyles.bodySmall(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Rename exercise',
                            onPressed: () => _showRenameDialog(exercise),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.statusError,
                              size: 20,
                            ),
                            tooltip: 'Delete exercise',
                            onPressed: () => _showDeleteDialog(exercise),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
