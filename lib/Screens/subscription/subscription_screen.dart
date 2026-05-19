import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/subscription_provider.dart';
import 'widgets/coins_unlock_note.dart';
import 'widgets/billing_toggle.dart';
import 'widgets/plan_card.dart';
import 'widgets/plan_toggle.dart';
import 'widgets/feature_row.dart';
import 'widgets/subscribe_button.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.free;
  bool _userSelected = false;
  bool _isYearly = false;

  static const _free = Color(0xFF9E9E9E);
  static const _pro = Color(0xFFFF6600);
  static const _proPlus = Color(0xFFFFB300);
  static const _black = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = context.watch<SubscriptionProvider>();
    final currentPlan = subscriptionProvider.currentPlan;
    final isPakistan = subscriptionProvider.isPakistan;
    if (!_userSelected) {
      _selectedPlan = currentPlan;
    }

    final planData = _planData();
    final currentInfo = planData[currentPlan]!;
    final selectedInfo = planData[_selectedPlan]!;

    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
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
        title: Text('Subscription', style: AppTextStyles.headingLarge()),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentPlanHeader(
                label: currentInfo.label,
                color: currentInfo.color,
              ),
              _ExpiryStatus(
                plan: currentPlan,
                proExpiry: subscriptionProvider.proExpiry,
                proPlusExpiry: subscriptionProvider.proPlusExpiry,
              ),
              const SizedBox(height: AppSpacing.lg),
              BillingToggle(
                isYearly: _isYearly,
                onChanged: (value) => setState(() => _isYearly = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              PlanToggle(
                selectedPlan: _selectedPlan,
                currentPlan: currentPlan,
                onChanged: (plan) {
                  setState(() {
                    _userSelected = true;
                    _selectedPlan = plan;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  final scale = Tween<double>(begin: 0.98, end: 1).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  );
                  return SlideTransition(
                    position: slide,
                    child: FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: scale, child: child),
                    ),
                  );
                },
                child: PlanCard(
                  key: ValueKey(_selectedPlan),
                  plan: _selectedPlan,
                  planName: selectedInfo.label,
                  planTagline: selectedInfo.tagline,
                  planIcon: selectedInfo.icon,
                  accentColor: selectedInfo.color,
                  isYearly: _isYearly,
                  isPakistan: isPakistan,
                  features: selectedInfo.features,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _ActionSection(
                currentPlan: currentPlan,
                selectedPlan: _selectedPlan,
                isYearly: _isYearly,
                onAction: () => _showComingSoon(context),
                onCoins: () => _showComingSoon(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<SubscriptionPlan, _PlanInfo> _planData() {
    return {
      SubscriptionPlan.free: _PlanInfo(
        label: 'Free',
        color: _free,
        icon: Icons.shield_outlined,
        tagline: 'Always Free',
        features: const [
          FeatureItem(text: 'Basic workout tracking', included: true),
          FeatureItem(text: 'Step tracking', included: true),
          FeatureItem(text: 'Water tracking', included: true),
          FeatureItem(text: 'Calories & macro tracking', included: true),
          FeatureItem(text: 'Body measurements', included: true),
          FeatureItem(text: '4 weeks training data stored', included: true),
          FeatureItem(
            text: '2 AI meal scans/day (with rewarded ad)',
            included: true,
          ),
          FeatureItem(
            text: '3 AI coach messages/day (with rewarded ad)',
            included: true,
          ),
          FeatureItem(text: 'Chat tab — locked', included: false),
          FeatureItem(text: 'Ads shown in app', included: false),
        ],
      ),
      SubscriptionPlan.pro: _PlanInfo(
        label: 'Pro',
        color: _pro,
        icon: Icons.bolt_rounded,
        tagline: 'Monthly plan',
        features: const [
          FeatureItem(text: 'Everything in Free', included: true),
          FeatureItem(text: 'No ads', included: true),
          FeatureItem(text: '8 weeks training data stored', included: true),
          FeatureItem(text: '3 AI meal scans per day', included: true),
          FeatureItem(text: '5 AI coach messages per day', included: true),
          FeatureItem(
            text: '60,000 AI trainer tokens per month',
            included: true,
          ),
          FeatureItem(text: 'Chat tab unlocked', included: true),
          FeatureItem(text: 'Can be unlocked with coins', included: true),
        ],
      ),
      SubscriptionPlan.proPlus: _PlanInfo(
        label: 'Pro+',
        color: _proPlus,
        icon: Icons.workspace_premium,
        tagline: 'Premium plan',
        features: const [
          FeatureItem(text: 'Everything in Pro', included: true),
          FeatureItem(text: '12 weeks training data stored', included: true),
          FeatureItem(text: 'Unlimited AI meal scans', included: true),
          FeatureItem(text: 'Unlimited AI coach messages', included: true),
          FeatureItem(
            text: '180,000 AI trainer tokens per month',
            included: true,
          ),
          FeatureItem(text: '1 AI diet plan per month', included: true),
          FeatureItem(text: '1 AI workout plan per month', included: true),
          FeatureItem(
            text: 'Discounts on human customized plans',
            included: true,
          ),
          FeatureItem(
            text: 'Cannot unlock with coins — payment only',
            included: false,
          ),
        ],
      ),
    };
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coming Soon'),
        backgroundColor: AppColors.backgroundTertiary,
      ),
    );
  }
}

class _PlanInfo {
  const _PlanInfo({
    required this.label,
    required this.color,
    required this.icon,
    required this.tagline,
    required this.features,
  });

  final String label;
  final Color color;
  final IconData icon;
  final String tagline;
  final List<FeatureItem> features;
}

class _CurrentPlanHeader extends StatelessWidget {
  const _CurrentPlanHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Current Plan:',
            style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(label, style: AppTextStyles.labelSmall(color: color)),
          ),
        ],
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({
    required this.currentPlan,
    required this.selectedPlan,
    required this.isYearly,
    required this.onAction,
    required this.onCoins,
  });

  final SubscriptionPlan currentPlan;
  final SubscriptionPlan selectedPlan;
  final bool isYearly;
  final VoidCallback onAction;
  final VoidCallback onCoins;

  static const _free = Color(0xFF9E9E9E);
  static const _pro = Color(0xFFFF6600);
  static const _proPlus = Color(0xFFFFB300);

  @override
  Widget build(BuildContext context) {
    final isLowerTier = _tier(selectedPlan) < _tier(currentPlan);
    final isSameTier = selectedPlan == currentPlan;

    Color color;
    bool enabled = true;
    bool outlined = false;
    String? helper;
    bool showCoins = false;

    if (selectedPlan == SubscriptionPlan.free) {
      color = _pro;
      showCoins = currentPlan == SubscriptionPlan.free;
    } else if (selectedPlan == SubscriptionPlan.pro) {
      color = _pro;
    } else {
      color = _proPlus;
      if (currentPlan == SubscriptionPlan.proPlus) {
        enabled = false;
        helper = 'You are on the best plan';
      }
    }

    if (isLowerTier) {
      helper ??= 'Downgrades are available soon';
    } else if (isSameTier && currentPlan == SubscriptionPlan.pro) {
      helper ??= 'You are on Pro plan';
    }

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.98, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: SubscribeButton(
            color: color,
            onPressed: onAction,
            currentPlan: currentPlan,
            selectedPlan: selectedPlan,
            isYearly: isYearly,
            enabled: enabled,
            outlined: outlined,
          ),
        ),
        if (showCoins) CoinsUnlockNote(onTap: onCoins),
        if (helper != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            helper!,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  int _tier(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 0;
      case SubscriptionPlan.pro:
        return 1;
      case SubscriptionPlan.proPlus:
        return 2;
    }
  }
}

class _ExpiryStatus extends StatelessWidget {
  const _ExpiryStatus({
    required this.plan,
    required this.proExpiry,
    required this.proPlusExpiry,
  });

  final SubscriptionPlan plan;
  final DateTime? proExpiry;
  final DateTime? proPlusExpiry;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formatter = DateFormat('dd MMM yyyy');

    String? text;
    Color? color;

    if (plan == SubscriptionPlan.pro) {
      if (proExpiry == null) {
        return const SizedBox.shrink();
      }
      if (now.isAfter(proExpiry!)) {
        text = 'Expired';
        color = AppColors.statusError;
      } else {
        text = 'Pro expires: ${formatter.format(proExpiry!)}';
        color = AppColors.textSecondary;
      }
    } else if (plan == SubscriptionPlan.proPlus) {
      if (proPlusExpiry == null) {
        return const SizedBox.shrink();
      }
      if (now.isAfter(proPlusExpiry!)) {
        text = 'Expired';
        color = AppColors.statusError;
      } else {
        text = 'Pro+ expires: ${formatter.format(proPlusExpiry!)}';
        color = AppColors.textSecondary;
      }
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(text!, style: AppTextStyles.bodySmall(color: color)),
    );
  }
}
