import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../subscription/subscription_screen.dart';

class ChatLockedScreen extends StatelessWidget {
  const ChatLockedScreen({super.key});

  static const Color _accent = Color(0xFFFF6600);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _accent.withOpacity(0.5),
                      width: 2,
                    ),
                    color: _accent.withOpacity(0.08),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: _accent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'AI Coach — Pro Feature',
                  style: AppTextStyles.headingLarge(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Unlock Chat to access your personal\nAI fitness coach',
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusLarge,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Upgrade to Pro',
                      style: AppTextStyles.headingSmall(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
