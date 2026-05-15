import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import '../../models/user_model.dart';
import '../../services/geo_service.dart';
import 'edit_age_screen.dart';
import 'edit_body_fat_screen.dart';
import 'edit_height_screen.dart';
import 'edit_macros_screen.dart';
import 'edit_steps_screen.dart';
import 'edit_weight_screen.dart';
import 'widgets/settings_widgets.dart';

class PersonalStatsScreen extends StatelessWidget {
  const PersonalStatsScreen({super.key});

  String _formatHeight(double cm) {
    if (cm <= 0) return '—';
    return '${cm.toStringAsFixed(0)} cm';
  }

  String _formatWeight(double kg, String unit) {
    if (kg <= 0) return '—';
    if (unit.toLowerCase() == 'lbs') {
      final lbs = kg / 0.45359237;
      return '${lbs.toStringAsFixed(1)} lbs';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<BrutlUserProvider>().user;
    final countryCode = (user as dynamic).countryCode as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Personal Stats'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsActionBoxWidget(
                children: [
                  SettingsTileWidget(
                    title: 'Gender',
                    trailingText: user.gender.isEmpty ? '—' : user.gender,
                    showChevron: false,
                    enabled: false,
                  ),
                  _CountryTile(countryCode: countryCode),
                  SettingsTileWidget(
                    title: 'Height',
                    trailingText: _formatHeight(user.height),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditHeightScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Weight',
                    trailingText: _formatWeight(user.weight, user.weightUnit),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditWeightScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Age',
                    trailingText: user.age <= 0 ? '—' : '${user.age}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditAgeScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Body Fat',
                    trailingText: user.bodyFatString.isEmpty
                        ? '—'
                        : user.bodyFatString,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditBodyFatScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Steps',
                    trailingText: user.dailySteps <= 0
                        ? '—'
                        : _withCommas(user.dailySteps),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditStepsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              SettingsActionBoxWidget(children: [_MacrosTile()]),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  String _withCommas(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.countryCode});

  final String countryCode;

  @override
  Widget build(BuildContext context) {
    final countryName = GeoService.countryName(countryCode);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Country',
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        countryName,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacrosTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<BrutlUserProvider>().user;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const EditMacrosScreen())),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Calories',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${user.targetCalories} kcal',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Carbs: ${user.targetCarbs}g  |  Protein: ${user.targetProtein}g  |  Fat: ${user.targetFats}g',
              style: AppTextStyles.bodySmall(),
            ),
          ],
        ),
      ),
    );
  }
}
