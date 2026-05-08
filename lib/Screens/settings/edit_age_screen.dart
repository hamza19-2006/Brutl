import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/brutl_user_provider.dart';
import 'widgets/biometric_recalc.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditAgeScreen extends StatefulWidget {
  const EditAgeScreen({super.key});

  @override
  State<EditAgeScreen> createState() => _EditAgeScreenState();
}

class _EditAgeScreenState extends State<EditAgeScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final age = context.read<BrutlUserProvider>().user.age;
    if (age > 0) _ctrl.text = age.toString();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_ctrl.text.trim());
    if (value == null || value < 12 || value > 100) {
      _showError('Please enter a valid age (12–100).');
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<BrutlUserProvider>();
    try {
      await provider.updateAge(value);
      // ignore: unawaited_futures
      recalcMaintenanceInBackground(provider.user);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update age. Please try again.');
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
      title: 'Age',
      isSaving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Age (years)'),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: const InputDecoration(
            hintText: '24',
            suffixText: 'yrs',
          ),
        ),
      ],
    );
  }
}
