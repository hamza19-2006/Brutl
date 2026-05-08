import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/settings_calculator_service.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditMacrosScreen extends StatefulWidget {
  const EditMacrosScreen({super.key});

  @override
  State<EditMacrosScreen> createState() => _EditMacrosScreenState();
}

class _EditMacrosScreenState extends State<EditMacrosScreen> {
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _carbsCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  bool _saving = false;
  int? _suggestedMaintenance;

  @override
  void initState() {
    super.initState();
    final user = context.read<BrutlUserProvider>().user;
    _calCtrl.text = user.targetCalories.toString();
    _carbsCtrl.text = user.targetCarbs.toString();
    _proteinCtrl.text = user.targetProtein.toString();
    _fatCtrl.text = user.targetFats.toString();
  }

  @override
  void dispose() {
    _calCtrl.dispose();
    _carbsCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  void _runSuggestion() {
    final user = context.read<BrutlUserProvider>().user;
    if (user.weight <= 0 || user.height <= 0 || user.age <= 0) {
      _showError(
        'Add your Height, Weight and Age in Personal Stats first.',
      );
      return;
    }

    final weightKg = user.weightUnit.toLowerCase() == 'lbs'
        ? user.weight * 0.45359237
        : user.weight;
    final heightCm = user.heightUnit.toLowerCase() == 'in'
        ? user.height * 2.54
        : user.height;

    final suggestion = SettingsCalculatorService.suggestMacros(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: user.age,
      gender: user.gender,
      dailyStepGoal: user.dailySteps,
      bodyFatAverage: user.bodyFatAverage,
      bodyGoal: user.bodyGoal,
    );

    setState(() {
      _calCtrl.text = suggestion.calories.toString();
      _carbsCtrl.text = suggestion.carbsGrams.toString();
      _proteinCtrl.text = suggestion.proteinGrams.toString();
      _fatCtrl.text = suggestion.fatGrams.toString();
      _suggestedMaintenance = suggestion.maintenanceCalories;
    });
  }

  Future<void> _save() async {
    final cal = int.tryParse(_calCtrl.text.trim());
    final carbs = int.tryParse(_carbsCtrl.text.trim());
    final protein = int.tryParse(_proteinCtrl.text.trim());
    final fat = int.tryParse(_fatCtrl.text.trim());

    if (cal == null || carbs == null || protein == null || fat == null) {
      _showError('All four fields are required.');
      return;
    }
    if (cal < 800 || cal > 6000) {
      _showError('Calories must be between 800 and 6,000.');
      return;
    }

    setState(() => _saving = true);
    final brutlUser = context.read<BrutlUserProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    try {
      await brutlUser.updateMacros(
        calories: cal,
        carbs: carbs,
        protein: protein,
        fats: fat,
        maintenanceCalories: _suggestedMaintenance,
      );

      // Sync to local fast paths consumed by Home / Nutrition screens.
      // ignore: unawaited_futures
      SharedPreferences.getInstance().then((prefs) async {
        await prefs.setInt('calorie_goal', cal);
        await prefs.setInt('carbs_goal', carbs);
        await prefs.setInt('protein_goal', protein);
        await prefs.setInt('fats_goal', fat);
      });
      // ignore: unawaited_futures
      workoutProvider.updateUser(dailyCalorieGoal: cal);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update macros. Please try again.');
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
    final user = context.watch<BrutlUserProvider>().user;
    return EditScreenScaffold(
      title: 'Macro Goals',
      isSaving: _saving,
      onSave: _save,
      children: [
        _MacroInputRow(
          label: 'Calories',
          unit: 'kcal',
          current: user.targetCalories.toString(),
          controller: _calCtrl,
        ),
        const SizedBox(height: AppSpacing.lg),
        _MacroInputRow(
          label: 'Carbs',
          unit: 'g',
          current: user.targetCarbs.toString(),
          controller: _carbsCtrl,
        ),
        const SizedBox(height: AppSpacing.lg),
        _MacroInputRow(
          label: 'Protein',
          unit: 'g',
          current: user.targetProtein.toString(),
          controller: _proteinCtrl,
        ),
        const SizedBox(height: AppSpacing.lg),
        _MacroInputRow(
          label: 'Fat',
          unit: 'g',
          current: user.targetFats.toString(),
          controller: _fatCtrl,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: OutlinedButton.icon(
            onPressed: _runSuggestion,
            icon: const Icon(
              Icons.auto_awesome,
              color: AppColors.accentPrimary,
              size: 18,
            ),
            label: Text(
              'Suggest from AI',
              style: AppTextStyles.headingSmall(
                color: AppColors.accentPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              side: const BorderSide(color: AppColors.accentPrimary),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusMedium),
              ),
            ),
          ),
        ),
        if (_suggestedMaintenance != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'Estimated maintenance: $_suggestedMaintenance kcal/day',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(),
            ),
          ),
      ],
    );
  }
}

class _MacroInputRow extends StatelessWidget {
  const _MacroInputRow({
    required this.label,
    required this.unit,
    required this.current,
    required this.controller,
  });

  final String label;
  final String unit;
  final String current;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.headingSmall(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Current: $current $unit',
                  style: AppTextStyles.labelSmall(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            decoration: InputDecoration(
              hintText: 'New $label',
              suffixText: unit,
            ),
          ),
        ),
      ],
    );
  }
}

