import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/workout_provider.dart';
import '../widgets/settings_widgets.dart';
import 'edit_exercises_screen.dart';

class EditDaysScreen extends StatelessWidget {
  const EditDaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Edit Days'),
      body: SafeArea(
        child: Consumer<WorkoutProvider>(
          builder: (context, provider, _) {
            final allDays = provider.activeSplitDays;
            final seen = <String>{};
            final days = allDays.where((d) => seen.add(d)).toList();

            if (days.isEmpty) {
              return Center(
                child: Text(
                  'No split configured.',
                  style: AppTextStyles.bodyMedium(),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              itemCount: days.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _DayRow(dayName: days[index]),
            );
          },
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.dayName});

  final String dayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditExercisesScreen(dayName: dayName),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusMedium,
                ),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(dayName, style: AppTextStyles.headingSmall()),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.edit,
            color: AppColors.textSecondary,
            size: 20,
          ),
          tooltip: 'Rename day',
          onPressed: () => _showRenameDialog(context),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: AppColors.statusError,
            size: 20,
          ),
          tooltip: 'Clear exercises',
          onPressed: () => _showClearConfirm(context),
        ),
      ],
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: dayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        title: Text('Rename Day', style: AppTextStyles.headingMedium()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter day name'),
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

    if (newName == null || newName.isEmpty || newName == dayName) return;
    if (!context.mounted) return;

    unawaited(
      context.read<WorkoutProvider>().renameDayOptimistic(dayName, newName),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Day renamed to "$newName".'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showClearConfirm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.statusError),
        ),
        title: Text(
          'Clear Day Exercises',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Are you sure? This will delete ALL exercises saved under '
          '"$dayName". The day itself will remain, but will be empty.',
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
              'Yes, Clear',
              style: AppTextStyles.headingSmall(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    unawaited(
      context.read<WorkoutProvider>().clearExercisesFromDayOptimistic(dayName),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Exercises for "$dayName" cleared.'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
