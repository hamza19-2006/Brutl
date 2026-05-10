import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Picker form for starting a friend-challenge.
///
/// Returns a `Map<String, dynamic>` payload via `Navigator.pop`:
/// `{title, type, durationDays, targetValue}`.
class StartChallengeScreen extends StatefulWidget {
  const StartChallengeScreen({super.key, required this.friendName});
  final String friendName;

  @override
  State<StartChallengeScreen> createState() => _StartChallengeScreenState();
}

class _StartChallengeScreenState extends State<StartChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  String _type = 'workout';
  int _durationDays = 7;
  int? _selectedPreset;

  static const List<_ChallengePreset> _presets = [
    _ChallengePreset(
      title: '7-Day Workout Streak',
      type: 'workout',
      durationDays: 7,
      targetValue: 7,
      hint: '7 workouts in 7 days',
    ),
    _ChallengePreset(
      title: '30-Day Consistency',
      type: 'consistency',
      durationDays: 30,
      targetValue: 30,
      hint: 'Log every day for a month',
    ),
    _ChallengePreset(
      title: 'Calorie Goal Streak',
      type: 'calories',
      durationDays: 7,
      targetValue: 7,
      hint: 'Hit your calorie goal 7 days in a row',
    ),
    _ChallengePreset(
      title: 'Step Master',
      type: 'steps',
      durationDays: 7,
      targetValue: 70000,
      hint: '10k steps daily for a week',
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _applyPreset(int index) {
    final preset = _presets[index];
    setState(() {
      _selectedPreset = index;
      _titleCtrl.text = preset.title;
      _targetCtrl.text = preset.targetValue.toString();
      _type = preset.type;
      _durationDays = preset.durationDays;
    });
  }

  void _start() {
    if (!_formKey.currentState!.validate()) return;
    final target = int.tryParse(_targetCtrl.text.trim());
    if (target == null || target <= 0) return;

    Navigator.pop<Map<String, dynamic>>(context, <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'type': _type,
      'durationDays': _durationDays,
      'targetValue': target,
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
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Start Challenge', style: AppTextStyles.headingLarge()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xl,
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentGlow,
                border: Border.all(color: AppColors.borderAccent),
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.accentPrimary,
                    size: 36,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Challenge ${widget.friendName}',
                          style: AppTextStyles.headingSmall(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Track progress side-by-side and see who finishes first',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Preset pickers
            _SectionLabel('Pick a preset'),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _presets.length; i++) ...[
              _PresetCard(
                preset: _presets[i],
                isSelected: _selectedPreset == i,
                onTap: () => _applyPreset(i),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Customise
            _SectionLabel('Or customise'),
            const SizedBox(height: AppSpacing.sm),

            _FieldLabel('Title'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('e.g. 7-Day Push-Up Challenge'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter a title'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            _FieldLabel('Type'),
            const SizedBox(height: 6),
            _TypeSelector(
              value: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpacing.lg),

            _FieldLabel('Duration'),
            const SizedBox(height: 6),
            _DurationSelector(
              value: _durationDays,
              onChanged: (d) => setState(() => _durationDays = d),
            ),
            const SizedBox(height: AppSpacing.lg),

            _FieldLabel('Target  (number to reach)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _targetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('e.g. 7 (workouts), 70000 (steps)'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter a positive target';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusSmall,
                    ),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  'Start Challenge',
                  style: AppTextStyles.headingSmall(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          AppTextStyles.bodyMedium(color: AppColors.textTertiary),
      filled: true,
      fillColor: AppColors.backgroundTertiary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
        borderSide: const BorderSide(color: AppColors.accentPrimary),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.headingSmall(),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelSmall(color: AppColors.textSecondary)
          .copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _ChallengePreset {
  const _ChallengePreset({
    required this.title,
    required this.type,
    required this.durationDays,
    required this.targetValue,
    required this.hint,
  });

  final String title;
  final String type;
  final int durationDays;
  final int targetValue;
  final String hint;
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final _ChallengePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _typeIcon {
    switch (preset.type) {
      case 'workout':
        return Icons.fitness_center_rounded;
      case 'calories':
        return Icons.local_fire_department_rounded;
      case 'steps':
        return Icons.directions_walk_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentSoft
              : AppColors.backgroundTertiary,
          border: Border.all(
            color: isSelected
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
          borderRadius:
              BorderRadius.circular(AppSpacing.borderRadiusMedium),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.backgroundQuaternary,
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusSmall),
              ),
              child: Icon(
                _typeIcon,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.accentPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.title, style: AppTextStyles.headingSmall()),
                  const SizedBox(height: 2),
                  Text(
                    preset.hint,
                    style: AppTextStyles.labelSmall(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accentPrimary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <_ChallengeTypeOption>[
    _ChallengeTypeOption(
      'workout',
      'Workout',
      Icons.fitness_center_rounded,
    ),
    _ChallengeTypeOption(
      'calories',
      'Calories',
      Icons.local_fire_department_rounded,
    ),
    _ChallengeTypeOption(
      'steps',
      'Steps',
      Icons.directions_walk_rounded,
    ),
    _ChallengeTypeOption(
      'consistency',
      'Consistency',
      Icons.check_circle_outline_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final opt in _options)
          InkWell(
            onTap: () => onChanged(opt.id),
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: value == opt.id
                    ? AppColors.accentSoft
                    : AppColors.backgroundTertiary,
                border: Border.all(
                  color: value == opt.id
                      ? AppColors.accentPrimary
                      : AppColors.borderDefault,
                ),
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusSmall,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.icon,
                    size: 18,
                    color: value == opt.id
                        ? AppColors.accentPrimary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    opt.label,
                    style: AppTextStyles.labelLarge(
                      color: value == opt.id
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ChallengeTypeOption {
  const _ChallengeTypeOption(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = <int>[7, 14, 30, 60];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final days in _options)
          InkWell(
            onTap: () => onChanged(days),
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusSmall),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: value == days
                    ? AppColors.accentSoft
                    : AppColors.backgroundTertiary,
                border: Border.all(
                  color: value == days
                      ? AppColors.accentPrimary
                      : AppColors.borderDefault,
                ),
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusSmall,
                ),
              ),
              child: Text(
                '$days days',
                style: AppTextStyles.labelLarge(
                  color: value == days
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
