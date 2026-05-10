import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Picker form for sharing a Personal Record into a chat.
///
/// Returns a `Map<String, dynamic>` payload via `Navigator.pop`:
/// `{exerciseName, weight, unit, reps, previousBest?}`.
class SharePRScreen extends StatefulWidget {
  const SharePRScreen({super.key});

  @override
  State<SharePRScreen> createState() => _SharePRScreenState();
}

class _SharePRScreenState extends State<SharePRScreen> {
  final _formKey = GlobalKey<FormState>();
  final _exerciseCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController(text: '1');
  final _previousCtrl = TextEditingController();
  String _unit = 'kg';

  @override
  void dispose() {
    _exerciseCtrl.dispose();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _previousCtrl.dispose();
    super.dispose();
  }

  void _share() {
    if (!_formKey.currentState!.validate()) return;
    final weight = double.tryParse(_weightCtrl.text.trim());
    final reps = int.tryParse(_repsCtrl.text.trim()) ?? 1;
    if (weight == null) return;

    final previous = double.tryParse(_previousCtrl.text.trim());

    Navigator.pop<Map<String, dynamic>>(context, <String, dynamic>{
      'exerciseName': _exerciseCtrl.text.trim(),
      'weight': weight,
      'unit': _unit,
      'reps': reps,
      if (previous != null && previous > 0) 'previousBest': previous,
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
        title: Text('Share PR', style: AppTextStyles.headingLarge()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Trophy header
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
                    Icons.emoji_events_rounded,
                    color: AppColors.accentPrimary,
                    size: 36,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Celebrate your win',
                          style: AppTextStyles.headingSmall(),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Share a personal record with your friend',
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

            // Exercise name
            _FieldLabel('Exercise'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _exerciseCtrl,
              textCapitalization: TextCapitalization.words,
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('e.g. Bench Press'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter an exercise name'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Weight + unit
            _FieldLabel('Weight'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]'),
                      ),
                    ],
                    style:
                        AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                    decoration: _decoration('100'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Enter a valid weight';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _UnitToggle(
                  value: _unit,
                  onChanged: (u) => setState(() => _unit = u),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Reps
            _FieldLabel('Reps'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _repsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('1'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) return 'Enter at least 1 rep';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Previous best (optional)
            _FieldLabel('Previous Best  (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _previousCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: _decoration('Show the gain over your last PR'),
            ),
            const SizedBox(height: AppSpacing.xxl),

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
                  'Share PR',
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

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        border: Border.all(color: AppColors.borderDefault),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final unit in const ['kg', 'lbs'])
            InkWell(
              onTap: () => onChanged(unit),
              borderRadius: BorderRadius.circular(
                AppSpacing.borderRadiusSmall,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: value == unit
                      ? AppColors.accentPrimary
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusSmall),
                ),
                child: Text(
                  unit,
                  style: AppTextStyles.labelLarge(
                    color: value == unit
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
