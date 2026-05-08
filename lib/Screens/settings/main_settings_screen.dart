import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/brutl_user_provider.dart';
import '../auth/login_screen.dart';
import 'account_settings_screen.dart';
import 'credentials/credentials_screen.dart';
import 'feedback_screen.dart';
import 'personal_stats_screen.dart';
import 'widgets/settings_widgets.dart';
import 'workout_settings/exercise_settings_screen.dart';

class MainSettingsScreen extends StatefulWidget {
  const MainSettingsScreen({super.key});

  @override
  State<MainSettingsScreen> createState() => _MainSettingsScreenState();
}

class _MainSettingsScreenState extends State<MainSettingsScreen> {
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    // Make sure the canonical Firestore user doc is bound for sub-screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrutlUserProvider>().bindToCurrentUser();
    });
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      await context.read<BrutlAuthProvider>().signOut();
    } catch (e) {
      debugPrint('SETTINGS: signOut threw — $e');
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    if (!mounted) return;
    try {
      await context.read<BrutlUserProvider>().clear();
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Settings'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsActionBoxWidget(
                children: [
                  SettingsTileWidget(
                    title: 'Account Setting',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountSettingsScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Personal Stats',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PersonalStatsScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Credentials',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CredentialsScreen(),
                      ),
                    ),
                  ),
                  SettingsTileWidget(
                    title: 'Exercise Changes',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ExerciseSettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              SettingsActionBoxWidget(
                children: [
                  SettingsTileWidget(
                    title: 'Contact Support',
                    onTap: () => _showComingSoon(context, 'Contact Support'),
                  ),
                  SettingsTileWidget(
                    title: 'Feedback / Suggestion',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FeedbackScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
              Center(
                child: SizedBox(
                  width: 220,
                  child: ElevatedButton(
                    onPressed: _loggingOut ? null : _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusError,
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
                    child: _loggingOut
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Logout',
                            style: AppTextStyles.headingSmall(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.backgroundTertiary,
          behavior: SnackBarBehavior.floating,
          content: Text('$label — coming soon'),
        ),
      );
  }
}
