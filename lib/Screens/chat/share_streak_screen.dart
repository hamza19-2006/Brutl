import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Picker form for sharing a streak.
///
/// Returns a `Map<String, dynamic>` payload via `Navigator.pop`:
/// `{streakDays, streakType, note?}`.
class ShareStreakScreen extends StatefulWidget {
  const ShareStreakScreen({super.key});

  @override
  State<ShareStreakScreen> createState() => _ShareStreakScreenState();
}

class _ShareStreakScreenState extends State<ShareStreakScreen> {
  final _formKey = GlobalKey<FormState>();
  final _daysCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'workout';

  @override
  void dispose() {
    _daysCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _share() {
    if (!_formKey.currentState!.validate()) return;
    final days = int.tryParse(_daysCtrl.text.trim());
    if (days == null || days <= 0) return;

    Navigator.pop<Map<String, dynamic>>(context, <String, dynamic>{
      'streakDays': days,
      'streakType': _type,
      if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
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
        title: Text('Share Streak', style: AppTextStyles.headingLarge()),
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
                  const Text('🔥', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show off your consistency',
                          style: AppTextStyles.headingSmall(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Share how many days you\'ve been on track',
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

            // Type
            _FieldLabel('What kind of streak?'),
            const SizedBox(height: 6),
            _TypeSelector(
              value: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Streak days
            _FieldLabel('Streak (days)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('e.g. 14'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Enter at least 1 day';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Note (optional)
            _FieldLabel('Note  (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('Add a quick word about your streak'),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _share,
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
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Share Streak',
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

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <_TypeOption>[
    _TypeOption('workout', 'Workout', Icons.fitness_center_rounded),
    _TypeOption('calories', 'Calories', Icons.local_fire_department_rounded),
    _TypeOption('general', 'General', Icons.bolt_rounded),
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

class _TypeOption {
  const _TypeOption(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}
