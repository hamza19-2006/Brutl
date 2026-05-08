import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import '../../providers/workout_provider.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditStepsScreen extends StatefulWidget {
  const EditStepsScreen({super.key});

  @override
  State<EditStepsScreen> createState() => _EditStepsScreenState();
}

class _EditStepsScreenState extends State<EditStepsScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final goal = context.read<BrutlUserProvider>().user.dailySteps;
    if (goal > 0) _ctrl.text = goal.toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_ctrl.text.trim());
    if (value == null || value < 1000 || value > 60000) {
      _showError('Enter a step goal between 1,000 and 60,000.');
      return;
    }
    setState(() => _saving = true);
    final brutlUser = context.read<BrutlUserProvider>();
    final workoutProvider = context.read<WorkoutProvider>();
    try {
      await brutlUser.updateStepsGoal(value);

      // Mirror to SharedPreferences (used by HomeScreen StepsCard) and
      // push into WorkoutProvider so the dotted goal-line in the Home
      // step-history chart updates immediately.
      // ignore: unawaited_futures
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setInt('step_goal', value),
      );
      // ignore: unawaited_futures
      workoutProvider.updateUser(dailyStepGoal: value);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update step goal. Please try again.');
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
      title: 'Steps',
      isSaving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Daily step goal'),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            hintText: '10000',
            suffixText: 'steps',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'This goal drives the dotted target line on the Home step '
            'history chart and feeds your TDEE estimate.',
            style: AppTextStyles.bodySmall(),
          ),
        ),
      ],
    );
  }
}
