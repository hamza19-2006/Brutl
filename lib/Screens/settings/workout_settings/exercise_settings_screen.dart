import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../widgets/settings_widgets.dart';
import 'edit_days_screen.dart';
import 'rep_ranges_screen.dart';
import 'split_change_screen.dart';

class ExerciseSettingsScreen extends StatelessWidget {
  const ExerciseSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Workout Settings'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: SettingsActionBoxWidget(
            children: [
              SettingsTileWidget(
                title: 'Split Change',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SplitChangeScreen(),
                  ),
                ),
              ),
              SettingsTileWidget(
                title: 'Edit Days & Exercises',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditDaysScreen(),
                  ),
                ),
              ),
              SettingsTileWidget(
                title: 'Rep Ranges',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RepRangesScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
