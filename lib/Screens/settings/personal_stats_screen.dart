// ═══════════════════════════════════════════════════════════════════════════════
// PERSONAL STATS SCREEN — with Water Goal row
// Replace lib/Screens/settings/personal_stats_screen.dart with this file.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import '../../providers/water_provider.dart';
import '../../services/geo_service.dart';
import 'body_measurements_screen.dart';
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
    final country = user.country;

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
                  SettingsTileWidget(
                    title: 'Country',
                    trailingText: _countryDisplayName(country),
                    showChevron: false,
                    enabled: false,
                  ),
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
                  _BodyMeasurementsTile(),
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
                  // ── Water Goal row (new) ─────────────────────────────────
                  _WaterGoalTile(),
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

  String _countryDisplayName(String country) {
    final trimmed = country.trim();
    if (trimmed.isEmpty) return '—';
    if (trimmed.length == 2) return GeoService.countryName(trimmed);
    return trimmed;
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

// ── Water Goal tile ───────────────────────────────────────────────────────────

class _WaterGoalTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (context, water, _) {
        final goalText = '${water.goalLiters.toStringAsFixed(1)} Liter';
        return InkWell(
          onTap: () => _showWaterGoalDialog(context, water),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Water Goal',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    goalText,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.textSecondary,
                    ),
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
          ),
        );
      },
    );
  }

  void _showWaterGoalDialog(BuildContext context, WaterProvider water) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _WaterGoalDialog(water: water),
    );
  }
}

// ── Water Goal Dialog ─────────────────────────────────────────────────────────

class _WaterGoalDialog extends StatefulWidget {
  const _WaterGoalDialog({required this.water});
  final WaterProvider water;

  @override
  State<_WaterGoalDialog> createState() => _WaterGoalDialogState();
}

class _WaterGoalDialogState extends State<_WaterGoalDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.water.goalLiters.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    final value = double.tryParse(text);
    if (value == null || value < 0.5) {
      setState(() => _error = 'Minimum goal is 0.5 L');
      return;
    }
    if (value > 10.0) {
      setState(() => _error = 'Maximum goal is 10.0 L');
      return;
    }

    await context.read<WaterProvider>().setGoal(value);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundTertiary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
        side: const BorderSide(color: AppColors.borderDefault),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.water_drop_rounded,
            color: Color(0xFF4FC3F7),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            'Water Goal',
            style: AppTextStyles.headingMedium(color: AppColors.textPrimary),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set your daily water goal (0.5 – 10.0 L)',
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              LengthLimitingTextInputFormatter(5),
            ],
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '4.0',
              suffixText: 'L',
              errorText: _error,
              filled: true,
              fillColor: AppColors.backgroundQuaternary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusMedium,
                ),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusMedium,
                ),
                borderSide: const BorderSide(color: AppColors.borderDefault),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusMedium,
                ),
                borderSide: const BorderSide(
                  color: Color(0xFF4FC3F7),
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            'Save',
            style: AppTextStyles.headingSmall(color: const Color(0xFF4FC3F7)),
          ),
        ),
      ],
    );
  }
}

// ── Macros Tile (unchanged from original) ─────────────────────────────────────

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

class _BodyMeasurementsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<BrutlUserProvider>().user;
    final raw = user.bodyMeasurements;
    final count = raw.isEmpty ? 4 : raw.length;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const BodyMeasurementsScreen(),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Body Measurements',
                style: AppTextStyles.bodyLarge(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$count parts',
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
      ),
    );
  }
}
