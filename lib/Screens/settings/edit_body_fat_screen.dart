import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import 'widgets/biometric_recalc.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditBodyFatScreen extends StatefulWidget {
  const EditBodyFatScreen({super.key});

  @override
  State<EditBodyFatScreen> createState() => _EditBodyFatScreenState();
}

class _EditBodyFatScreenState extends State<EditBodyFatScreen> {
  static const List<String> _ranges = [
    '5% to 10%',
    '11% to 15%',
    '16% to 20%',
    '21% to 25%',
    '26% to 30%',
    '31% to 35%',
    '36% to 40%',
    '40%+',
  ];

  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<BrutlUserProvider>().user.bodyFatString;
    if (current.isNotEmpty && _ranges.contains(current)) {
      _selected = current;
    }
  }

  double _averageOf(String label) {
    if (label == '40%+') return 45;
    final parts = label.replaceAll('%', '').split(' to ');
    if (parts.length != 2) return 0;
    final lo = double.tryParse(parts[0].trim()) ?? 0;
    final hi = double.tryParse(parts[1].trim()) ?? 0;
    return (lo + hi) / 2.0;
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) {
      _showError('Please select a body-fat range.');
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<BrutlUserProvider>();
    try {
      await provider.updateBodyFat(
        label: selected,
        average: _averageOf(selected),
      );
      // ignore: unawaited_futures
      recalcMaintenanceInBackground(provider.user);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update body fat. Please try again.');
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

  void _showReferenceModal() {
    final user = context.read<BrutlUserProvider>().user;
    final gender = user.gender.toLowerCase();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusXXL),
        ),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        Widget content;
        if (gender == 'male') {
          content = Image.asset(
            'assets/Images/Male_BodyFat.png',
            fit: BoxFit.contain,
          );
        } else if (gender == 'female') {
          content = Image.asset(
            'assets/Images/Female_BodyFat.png',
            fit: BoxFit.contain,
          );
        } else {
          content = Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body Fat Reference',
                  style: AppTextStyles.headingMedium(),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final range in _ranges)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '• $range — ${_describeRange(range)}',
                      style: AppTextStyles.bodyMedium(),
                    ),
                  ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.borderDefault,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Flexible(child: content),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _describeRange(String range) {
    switch (range) {
      case '5% to 10%':
        return 'Competitive lean — visible vascularity.';
      case '11% to 15%':
        return 'Athletic — defined abs.';
      case '16% to 20%':
        return 'Fit — toned with mild definition.';
      case '21% to 25%':
        return 'Average — soft midsection.';
      case '26% to 30%':
        return 'Above average — visible weight gain.';
      case '31% to 35%':
        return 'Higher — measurable health risk markers.';
      case '36% to 40%':
        return 'Significant — focused fat-loss recommended.';
      default:
        return 'Severe — consult a clinician.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditScreenScaffold(
      title: 'Body Fat',
      isSaving: _saving,
      onSave: _save,
      saveEnabled: _selected != null,
      children: [
        const FieldLabel('Estimated body-fat range'),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundQuaternary,
            borderRadius:
                BorderRadius.circular(AppSpacing.borderRadiusMedium),
            border: Border.all(color: AppColors.borderDefault),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selected,
              isExpanded: true,
              hint: Text(
                'Select range',
                style: AppTextStyles.bodyMedium(),
              ),
              dropdownColor: AppColors.backgroundTertiary,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
              style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
              items: [
                for (final r in _ranges)
                  DropdownMenuItem<String>(value: r, child: Text(r)),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GestureDetector(
          onTap: _showReferenceModal,
          child: Text(
            "Don't know about body fat? Click here!",
            style: AppTextStyles.bodyMedium(color: AppColors.accentPrimary)
                .copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}
