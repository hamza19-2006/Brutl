import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../widgets/settings_widgets.dart';
import 'edit_email_screen.dart';
import 'edit_password_screen.dart';

/// Entry-point screen for the Credentials settings section.
///
/// Displays two tiles — [Email] and [Password] — inside a grouped
/// [SettingsActionBoxWidget].  The Email tile shows the user's current
/// [FirebaseAuth] email as a greyed-out trailing hint so they always know
/// which address is registered.
///
/// Navigation targets:
/// - [EditEmailScreen]    — two-step email-change flow.
/// - [EditPasswordScreen] — three-field password-update form.
class CredentialsScreen extends StatelessWidget {
  const CredentialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// Read the current email synchronously from [FirebaseAuth].
    /// This is intentionally NOT reactive because [currentUser.email] only
    /// changes after the user clicks the verification link in their new inbox —
    /// at which point the app will rebuild naturally via auth state changes.
    final String email =
        FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Credentials'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              /// Grouped box containing Email and Password tiles.
              SettingsActionBoxWidget(
                children: [
                  /// ── EMAIL TILE ────────────────────────────────────────────
                  /// Trailing text shows the current registered email (ellipsed
                  /// if long) so the user has immediate context before tapping.
                  SettingsTileWidget(
                    title: 'Email',
                    trailingText: email.isNotEmpty ? email : '—',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditEmailScreen(),
                      ),
                    ),
                  ),

                  /// ── PASSWORD TILE ─────────────────────────────────────────
                  SettingsTileWidget(
                    title: 'Password',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditPasswordScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
