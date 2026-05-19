import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class BillingToggle extends StatelessWidget {
  const BillingToggle({
    super.key,
    required this.isYearly,
    required this.onChanged,
  });

  final bool isYearly;
  final ValueChanged<bool> onChanged;

  static const _toggleBg = Color(0xFF1E1E1E);
  static const _saveBadge = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _toggleBg,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              _buildOption(
                label: 'Monthly',
                selected: !isYearly,
                onTap: () => onChanged(false),
              ),
              _buildOption(
                label: 'Yearly',
                selected: isYearly,
                onTap: () => onChanged(true),
              ),
            ],
          ),
        ),
        if (isYearly)
          Positioned(
            top: -8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: _saveBadge,
                borderRadius: BorderRadius.circular(
                  AppSpacing.borderRadiusFull,
                ),
              ),
              child: Text(
                'Save 10%',
                style: AppTextStyles.labelSmall(color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.headingSmall(
              color: selected ? Colors.black : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
