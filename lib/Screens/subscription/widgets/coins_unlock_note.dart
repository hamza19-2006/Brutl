import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class CoinsUnlockNote extends StatelessWidget {
  const CoinsUnlockNote({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          'Or unlock Pro with coins',
          style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
