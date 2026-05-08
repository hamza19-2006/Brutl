import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/brutl_user_provider.dart';
import '../widgets/settings_widgets.dart';

class RepRangesScreen extends StatefulWidget {
  const RepRangesScreen({super.key});

  @override
  State<RepRangesScreen> createState() => _RepRangesScreenState();
}

class _RepRangesScreenState extends State<RepRangesScreen> {
  late RangeValues _compoundValues;
  late RangeValues _isolationValues;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<BrutlUserProvider>().user;
    _compoundValues = RangeValues(
      user.compoundRepMin.toDouble(),
      user.compoundRepMax.toDouble(),
    );
    _isolationValues = RangeValues(
      user.isolationRepMin.toDouble(),
      user.isolationRepMax.toDouble(),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await context.read<BrutlUserProvider>().updateRepRanges(
            compoundMin: _compoundValues.start.toInt(),
            compoundMax: _compoundValues.end.toInt(),
            isolationMin: _isolationValues.start.toInt(),
            isolationMax: _isolationValues.end.toInt(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Rep ranges saved.'),
            backgroundColor: AppColors.statusSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Could not save rep ranges. Please try again.',
            ),
            backgroundColor: AppColors.statusError,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Rep Ranges'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SliderSection(
                      title: 'Compound Exercises',
                      values: _compoundValues,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      onChanged: (v) =>
                          setState(() => _compoundValues = v),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _SliderSection(
                      title: 'Isolation Exercises',
                      values: _isolationValues,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (v) =>
                          setState(() => _isolationValues = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.backgroundQuaternary,
                    disabledForegroundColor: AppColors.textTertiary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusMedium,
                      ),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Rep Ranges',
                          style: AppTextStyles.headingSmall(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderSection extends StatelessWidget {
  const _SliderSection({
    required this.title,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headingSmall()),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Current: ${values.start.toInt()} – ${values.end.toInt()} reps',
            style: AppTextStyles.bodyMedium(color: AppColors.accentPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accentPrimary,
              inactiveTrackColor: AppColors.backgroundQuaternary,
              thumbColor: AppColors.accentPrimary,
              overlayColor: AppColors.accentGlow,
              valueIndicatorColor: AppColors.accentPrimary,
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
            ),
            child: RangeSlider(
              values: values,
              min: min,
              max: max,
              divisions: divisions,
              labels: RangeLabels(
                values.start.toInt().toString(),
                values.end.toInt().toString(),
              ),
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.toInt()} rep',
                style: AppTextStyles.labelSmall(),
              ),
              Text(
                '${max.toInt()} reps',
                style: AppTextStyles.labelSmall(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
