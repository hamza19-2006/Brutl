import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import 'widgets/biometric_recalc.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditWeightScreen extends StatefulWidget {
  const EditWeightScreen({super.key});

  @override
  State<EditWeightScreen> createState() => _EditWeightScreenState();
}

class _EditWeightScreenState extends State<EditWeightScreen> {
  static const _kg = 'kg';
  static const _lbs = 'lbs';
  String _unit = _kg;
  bool _saving = false;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<BrutlUserProvider>().user;
    if (user.weight > 0) {
      _ctrl.text = user.weight.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onUnitChanged(String unit) {
    final raw = double.tryParse(_ctrl.text.trim());
    if (raw != null && unit != _unit) {
      final converted = unit == _lbs ? raw / 0.45359237 : raw * 0.45359237;
      _ctrl.text = converted.toStringAsFixed(1);
    }
    setState(() => _unit = unit);
  }

  Future<void> _save() async {
    final raw = double.tryParse(_ctrl.text.trim());
    if (raw == null || raw <= 0) {
      _showError('Please enter a valid weight.');
      return;
    }
    final kg = _unit == _lbs ? raw * 0.45359237 : raw;
    if (kg < 25 || kg > 350) {
      _showError('Please enter a realistic weight.');
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<BrutlUserProvider>();
    try {
      await provider.updateWeight(
        valueKg: double.parse(kg.toStringAsFixed(2)),
        displayUnit: _unit,
      );
      // ignore: unawaited_futures
      recalcMaintenanceInBackground(provider.user);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update weight. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.statusError,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return EditScreenScaffold(
      title: 'Weight',
      isSaving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Unit'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusMedium),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              for (final option in const [_kg, _lbs])
                Expanded(
                  child: GestureDetector(
                    onTap: () => _onUnitChanged(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _unit == option
                            ? AppColors.accentPrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusSmall,
                        ),
                      ),
                      child: Text(
                        option.toUpperCase(),
                        style: AppTextStyles.headingSmall(
                          color: _unit == option
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: _unit == _kg ? '70.5' : '155.5',
            suffixText: _unit,
          ),
        ),
      ],
    );
  }
}
