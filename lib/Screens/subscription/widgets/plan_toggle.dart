import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/subscription_provider.dart';

class PlanToggle extends StatelessWidget {
  const PlanToggle({
    super.key,
    required this.selectedPlan,
    required this.currentPlan,
    required this.onChanged,
  });

  final SubscriptionPlan selectedPlan;
  final SubscriptionPlan currentPlan;
  final ValueChanged<SubscriptionPlan> onChanged;

  static const _toggleBg = Color(0xFF1E1E1E);
  static const _free = Color(0xFF9E9E9E);
  static const _pro = Color(0xFFFF6600);
  static const _proPlus = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _toggleBg,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: SubscriptionPlan.values.map((plan) {
              final isSelected = plan == selectedPlan;
              final color = _planColor(plan);
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(plan),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusFull,
                      ),
                    ),
                    child: Text(
                      _planLabel(plan),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingSmall(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: SubscriptionPlan.values.map((plan) {
            return Expanded(
              child: Center(
                child: plan == currentPlan
                    ? Text(
                        'Current',
                        style: AppTextStyles.labelSmall(
                          color: _planColor(plan),
                        ),
                      )
                    : const SizedBox(height: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _planColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.pro:
        return _pro;
      case SubscriptionPlan.proPlus:
        return _proPlus;
      case SubscriptionPlan.free:
      default:
        return _free;
    }
  }

  String _planLabel(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.proPlus:
        return 'Pro+';
      case SubscriptionPlan.free:
      default:
        return 'Free';
    }
  }
}
