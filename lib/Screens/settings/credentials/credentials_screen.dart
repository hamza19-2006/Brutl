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
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key});

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  void _showRefreshErrorSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusError,
          content: Text(
            'Could not refresh your latest email right now.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  Future<void> _refreshUser() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'CREDENTIALS_SCREEN: Failed to reload Firebase user — ${error.toString()}',
      );
      _showRefreshErrorSnackBar();
    } catch (error) {
      debugPrint(
        'CREDENTIALS_SCREEN: Unexpected user reload failure — ${error.toString()}',
      );
      _showRefreshErrorSnackBar();
    }
    // Rebuild so `currentUser?.email` is re-read after reload().
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    /// Read the current email synchronously from [FirebaseAuth].
    /// This is intentionally NOT reactive because [currentUser.email] only
    /// changes after the user clicks the verification link in their new inbox —
    /// at which point the app will rebuild naturally via auth state changes.
    final String email = FirebaseAuth.instance.currentUser?.email ?? '';

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
