import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/subscription_provider.dart';

class SubscribeButton extends StatelessWidget {
  const SubscribeButton({
    super.key,
    required this.color,
    required this.onPressed,
    required this.currentPlan,
    required this.selectedPlan,
    required this.isYearly,
    this.enabled = true,
    this.outlined = false,
  });

  final Color color;
  final VoidCallback onPressed;
  final SubscriptionPlan currentPlan;
  final SubscriptionPlan selectedPlan;
  final bool isYearly;
  final bool enabled;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.headingSmall(
      color: outlined ? color : Colors.white,
    );
    final label = _resolveLabel();

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.6)),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
            ),
          ),
          child: Text(label, style: textStyle),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.backgroundQuaternary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: enabled
              ? textStyle
              : AppTextStyles.headingSmall(color: AppColors.textDisabled),
        ),
      ),
    );
  }

  String _resolveLabel() {
    if (selectedPlan == SubscriptionPlan.free) {
      return 'Upgrade to Pro';
    }

    if (selectedPlan == SubscriptionPlan.proPlus &&
        currentPlan == SubscriptionPlan.proPlus) {
      return 'Current Plan';
    }

    if (selectedPlan == SubscriptionPlan.pro ||
        selectedPlan == SubscriptionPlan.proPlus) {
      return isYearly ? 'Subscribe Yearly' : 'Subscribe Monthly';
    }

    return 'Subscribe Monthly';
  }
}
