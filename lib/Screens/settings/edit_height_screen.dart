import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import 'widgets/biometric_recalc.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditHeightScreen extends StatefulWidget {
  const EditHeightScreen({super.key});

  @override
  State<EditHeightScreen> createState() => _EditHeightScreenState();
}

class _EditHeightScreenState extends State<EditHeightScreen> {
  static const _cm = 'cm';
  static const _ftIn = 'ft/in';
  String _unit = _cm;
  bool _saving = false;

  final TextEditingController _cmCtrl = TextEditingController();
  final TextEditingController _ftCtrl = TextEditingController();
  final TextEditingController _inCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<BrutlUserProvider>().user;
    if (user.height > 0) {
      _cmCtrl.text = user.height.toStringAsFixed(0);
      final totalIn = user.height / 2.54;
      final ft = totalIn ~/ 12;
      final inch = (totalIn - ft * 12).round();
      _ftCtrl.text = ft.toString();
      _inCtrl.text = inch.toString();
    }
  }

  @override
  void dispose() {
    _cmCtrl.dispose();
    _ftCtrl.dispose();
    _inCtrl.dispose();
    super.dispose();
  }

  double? _heightCm() {
    if (_unit == _cm) {
      return double.tryParse(_cmCtrl.text.trim());
    }
    final ft = int.tryParse(_ftCtrl.text.trim());
    final inch = int.tryParse(_inCtrl.text.trim()) ?? 0;
    if (ft == null) return null;
    final totalIn = ft * 12 + inch;
    return totalIn * 2.54;
  }

  Future<void> _save() async {
    final cm = _heightCm();
    if (cm == null || cm < 80 || cm > 260) {
      _showError('Please enter a realistic height.');
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<BrutlUserProvider>();
    try {
      await provider.updateHeight(valueCm: double.parse(cm.toStringAsFixed(1)));
      // Background recalc; do not block UX.
      // ignore: unawaited_futures
      recalcMaintenanceInBackground(provider.user);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update height. Please try again.');
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
      title: 'Height',
      isSaving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Unit'),
        _UnitToggle(
          options: const [_cm, _ftIn],
          selected: _unit,
          onChanged: (value) => setState(() => _unit = value),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_unit == _cm)
          TextField(
            controller: _cmCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: '175',
              suffixText: 'cm',
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ftCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '5',
                    suffixText: 'ft',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _inCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '9',
                    suffixText: 'in',
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Stored canonically in centimetres.',
          style: AppTextStyles.bodySmall(),
        ),
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == option
                        ? AppColors.accentPrimary
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.borderRadiusSmall),
                  ),
                  child: Text(
                    option.toUpperCase(),
                    style: AppTextStyles.headingSmall(
                      color: selected == option
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
