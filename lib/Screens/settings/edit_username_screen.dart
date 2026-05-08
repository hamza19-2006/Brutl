import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/brutl_user_provider.dart';
import 'widgets/edit_screen_scaffold.dart';

class EditUsernameScreen extends StatefulWidget {
  const EditUsernameScreen({super.key});

  @override
  State<EditUsernameScreen> createState() => _EditUsernameScreenState();
}

class _EditUsernameScreenState extends State<EditUsernameScreen> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorText;

  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_\.]{3,24}$');

  @override
  void initState() {
    super.initState();
    final current = context.read<BrutlUserProvider>().user.username;
    _controller = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<BrutlUserProvider>();
    final value = _controller.text.trim().toLowerCase();

    final blockedUntil = provider.usernameNextChangeAllowedAt();
    if (blockedUntil != null) {
      final formatted = DateFormat('MMM d, y').format(blockedUntil);
      setState(() => _errorText = 'You can change again on $formatted.');
      return;
    }

    if (!_usernamePattern.hasMatch(value)) {
      setState(
        () => _errorText =
            'Use 3–24 chars: lowercase letters, numbers, "_" or "."',
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final available = await provider.isUsernameAvailable(value);
      if (!available) {
        setState(() {
          _saving = false;
          _errorText = 'That username is already taken.';
        });
        return;
      }
      await provider.updateUsername(value);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = 'Could not update username. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedUntil = context.select<BrutlUserProvider, DateTime?>(
      (p) => p.usernameNextChangeAllowedAt(),
    );

    return EditScreenScaffold(
      title: 'Username',
      isSaving: _saving,
      saveEnabled: blockedUntil == null,
      onSave: _save,
      children: [
        const FieldLabel('Username'),
        TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\.]')),
            LengthLimitingTextInputFormatter(24),
          ],
          decoration: InputDecoration(
            prefixText: '@',
            prefixStyle: AppTextStyles.bodyLarge(
              color: AppColors.textSecondary,
            ),
            hintText: 'your_handle',
            errorText: _errorText,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Note: You can only change once a month.',
          style: AppTextStyles.bodySmall(),
        ),
        if (blockedUntil != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Next change allowed on ${DateFormat('MMM d, y').format(blockedUntil)}.',
            style: AppTextStyles.bodySmall(color: AppColors.statusWarning),
          ),
        ],
      ],
    );
  }
}
