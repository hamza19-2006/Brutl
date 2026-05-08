import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/brutl_models.dart' as brutl;
import '../../../providers/workout_provider.dart';
import '../widgets/settings_widgets.dart';
import 'edit_exercises_screen.dart';

class EditDaysScreen extends StatefulWidget {
  const EditDaysScreen({super.key});

  @override
  State<EditDaysScreen> createState() => _EditDaysScreenState();
}

class _EditDaysScreenState extends State<EditDaysScreen> {
  int _selectedWeekIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Edit Days'),
      body: SafeArea(
        child: Consumer<WorkoutProvider>(
          builder: (context, provider, _) {
            final maxWeekIndex = provider.totalProgramWeeks - 1;
            if (_selectedWeekIndex > maxWeekIndex) {
              _selectedWeekIndex = maxWeekIndex < 0 ? 0 : maxWeekIndex;
            }

            final days = provider.getDaysForWeek(_selectedWeekIndex);

            return Column(
              children: [
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    itemCount: provider.totalProgramWeeks,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedWeekIndex == index;
                      final weekNumber = index + 1;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedWeekIndex = index);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF3D00)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Text(
                            'Week $weekNumber',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF888888),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: days.isEmpty
                      ? Center(
                          child: Text(
                            'No workouts configured for this week.',
                            style: AppTextStyles.bodyMedium(),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                          itemCount: days.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) => _DayRow(
                            weekIndex: _selectedWeekIndex,
                            day: days[index],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.weekIndex, required this.day});

  final int weekIndex;
  final brutl.ProgramDayModel day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditExercisesScreen(
                  dayId: day.id,
                  dayName: day.splitName,
                  weekIndex: weekIndex,
                ),
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
              child: Text(day.splitName, style: AppTextStyles.headingSmall()),
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
    final controller = TextEditingController(text: day.splitName);
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

    if (newName == null || newName.isEmpty || newName == day.splitName) return;
    if (!context.mounted) return;

    unawaited(
      context.read<WorkoutProvider>().renameDayOptimistic(
        weekIndex,
        day.splitName,
        newName,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Day renamed to "$newName".',
            style: const TextStyle(color: Colors.white),
          ),
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
          '"${day.splitName}". The day itself will remain, but will be empty.',
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
      context.read<WorkoutProvider>().clearExercisesFromDayOptimistic(
        weekIndex,
        day.splitName,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Exercises for "${day.splitName}" cleared.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
