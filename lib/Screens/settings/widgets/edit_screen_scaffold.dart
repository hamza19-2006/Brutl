import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'settings_widgets.dart';

/// Standard layout for every "Edit X" sub-screen so visuals stay consistent.
class EditScreenScaffold extends StatelessWidget {
  const EditScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.isSaving = false,
    this.saveLabel = 'Save',
    this.saveEnabled = true,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final bool isSaving;
  final String saveLabel;
  final bool saveEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, title),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isSaving || !saveEnabled) ? null : onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusMedium,
                      ),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          saveLabel,
                          style: AppTextStyles.headingSmall(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Brutal-style label rendered above an input field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.labelLarge()),
    );
  }
}
