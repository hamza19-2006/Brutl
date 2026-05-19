import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/subscription_provider.dart';
import 'feature_row.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.planName,
    required this.planTagline,
    required this.planIcon,
    required this.accentColor,
    required this.isYearly,
    required this.isPakistan,
    required this.features,
  });

  final SubscriptionPlan plan;
  final String planName;
  final String planTagline;
  final IconData planIcon;
  final Color accentColor;
  final bool isYearly;
  final bool isPakistan;
  final List<FeatureItem> features;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan == SubscriptionPlan.proPlus;
    return Transform.scale(
      scale: isPremium ? 1.02 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF141414), Color(0xFF1C1C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXL),
          border: Border.all(color: accentColor.withOpacity(0.7), width: 1),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(isPremium ? 0.35 : 0.18),
              blurRadius: isPremium ? 20 : 14,
              offset: const Offset(0, 6),
            ),
            const BoxShadow(
              color: AppColors.elevatedShadow,
              blurRadius: 18,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusMedium,
                          ),
                          border: Border.all(
                            color: accentColor.withOpacity(0.6),
                          ),
                        ),
                        child: Icon(planIcon, color: accentColor, size: 26),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            planName,
                            style: AppTextStyles.displayMedium(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            planTagline,
                            style: AppTextStyles.bodySmall(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _PriceSection(
                  plan: plan,
                  accentColor: accentColor,
                  isYearly: isYearly,
                  isPakistan: isPakistan,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              height: 1,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.7),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Column(
              children: [
                for (var i = 0; i < features.length; i++)
                  FeatureRow(
                    key: ValueKey('${plan.name}-$i'),
                    item: features[i],
                    accentColor: accentColor,
                    index: i,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection({
    required this.plan,
    required this.accentColor,
    required this.isYearly,
    required this.isPakistan,
  });

  final SubscriptionPlan plan;
  final Color accentColor;
  final bool isYearly;
  final bool isPakistan;

  @override
  Widget build(BuildContext context) {
    final price = _priceInfo();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(price.primary),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            price.primary,
            textAlign: TextAlign.right,
            style: AppTextStyles.displayLarge(
              color: plan == SubscriptionPlan.free
                  ? AppColors.textPrimary
                  : accentColor,
            ),
          ),
          if (price.crossedOut != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              price.crossedOut!,
              style: AppTextStyles.bodySmall(
                color: AppColors.textTertiary,
              ).copyWith(decoration: TextDecoration.lineThrough),
              textAlign: TextAlign.right,
            ),
          ],
          if (price.effectiveMonthly != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              price.effectiveMonthly!,
              style: AppTextStyles.labelSmall(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }

  _PriceInfo _priceInfo() {
    switch (plan) {
      case SubscriptionPlan.free:
        return _PriceInfo(
          primary: isPakistan ? 'PKR 0' : '\$0',
        );
      case SubscriptionPlan.pro:
        if (isYearly) {
          return _PriceInfo(
            primary: isPakistan ? 'PKR 4,311/year' : '\$107.89/year',
            crossedOut: isPakistan ? 'PKR 399/mo' : '\$9.99/mo',
            effectiveMonthly: isPakistan
                ? 'PKR 359/mo effective'
                : '\$8.99/mo effective',
          );
        }
        return _PriceInfo(
          primary: isPakistan ? 'PKR 399/month' : '\$9.99/month',
        );
      case SubscriptionPlan.proPlus:
        if (isYearly) {
          return _PriceInfo(
            primary: isPakistan ? 'PKR 10,791/year' : '\$194.29/year',
            crossedOut: isPakistan ? 'PKR 999/mo' : '\$17.99/mo',
            effectiveMonthly: isPakistan
                ? 'PKR 899/mo effective'
                : '\$16.19/mo effective',
          );
        }
        return _PriceInfo(
          primary: isPakistan ? 'PKR 999/month' : '\$17.99/month',
        );
    }
  }
}

class _PriceInfo {
  const _PriceInfo({
    required this.primary,
    this.crossedOut,
    this.effectiveMonthly,
  });

  final String primary;
  final String? crossedOut;
  final String? effectiveMonthly;
}
