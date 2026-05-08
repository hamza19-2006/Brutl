import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/brutl_user_provider.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditNameScreen extends StatefulWidget {
  const EditNameScreen({super.key});

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<BrutlUserProvider>().user.displayName;
    _controller = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      _showError('Name cannot be empty.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<BrutlUserProvider>().updateDisplayName(value);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      _showError('Could not update your name. Please try again.');
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
      title: 'Name',
      isSaving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Display name'),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
        ),
      ],
    );
  }
}
