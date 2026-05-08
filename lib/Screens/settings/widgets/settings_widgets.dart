import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Reusable single-row tile used inside a [SettingsActionBoxWidget].
class SettingsTileWidget extends StatelessWidget {
  const SettingsTileWidget({
    super.key,
    required this.title,
    this.trailingText,
    this.onTap,
    this.showChevron = true,
    this.enabled = true,
    this.leading,
  });

  final String title;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool enabled;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textPrimary : AppColors.textTertiary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyLarge(color: color),
              ),
            ),
            if (trailingText != null) ...[
              Flexible(
                child: Text(
                  trailingText!,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (showChevron)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Card/Boxed list container that groups multiple [SettingsTileWidget]s.
class SettingsActionBoxWidget extends StatelessWidget {
  const SettingsActionBoxWidget({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i != children.length - 1) {
        separated.add(
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderSubtle,
            indent: AppSpacing.lg,
            endIndent: AppSpacing.lg,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: separated,
      ),
    );
  }
}

/// Brutal-style primary AppBar used by all settings sub-screens.
AppBar buildSettingsAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppColors.backgroundPrimary,
    elevation: 0,
    titleSpacing: 0,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new,
        color: AppColors.textPrimary,
        size: 20,
      ),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    title: Text(
      title,
      style: AppTextStyles.headingLarge(),
    ),
    centerTitle: false,
  );
}
