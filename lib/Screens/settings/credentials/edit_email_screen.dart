import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/edit_screen_scaffold.dart';
import '../widgets/settings_widgets.dart';

/// Two-step email-change flow contained within a single [StatefulWidget].
///
/// **Step 1 — Verify Current Password** (`_currentStep == 1`)
/// The user re-authenticates via [EmailAuthProvider.credential] +
/// [User.reauthenticateWithCredential].  A "Forgot Password?" link appears
/// dynamically only after a failed attempt (i.e. [_showForgotLink] == true).
///
/// **Step 2 — Enter New Email** (`_currentStep == 2`)
/// The user enters a new address which is validated against [_emailRegex]
/// before calling [User.verifyBeforeUpdateEmail].  A success bottom-sheet
/// explains that the change only takes effect after the user clicks the link
/// in their **new** inbox — Firebase does NOT update [currentUser.email]
/// instantly, so no optimistic local state is set.
///
/// **Firestore Note:** Email is stored separately in the `users` collection.
/// Per the Data Synchronisation directive this screen intentionally does NOT
/// write the new email to Firestore — that must only happen after the user
/// clicks the Firebase verification link and [currentUser.email] is confirmed
/// to have changed.
class EditEmailScreen extends StatefulWidget {
  const EditEmailScreen({super.key});

  @override
  State<EditEmailScreen> createState() => _EditEmailScreenState();
}

class _EditEmailScreenState extends State<EditEmailScreen> {
  // ── Step tracking ──────────────────────────────────────────────────────────

  /// Which phase of the flow is active.
  /// `1` = verify current password.  `2` = enter new email.
  int _currentStep = 1;

  /// Becomes `true` after the first failed re-authentication, causing the
  /// "Forgot Password? Reset it here." link to appear below the password field.
  bool _showForgotLink = false;

  /// Guards the action button and wraps the body in [AbsorbPointer] to prevent
  /// double-submission or stale taps during Firebase round-trips.
  bool _loading = false;

  // ── State captured at init ─────────────────────────────────────────────────

  /// The email currently registered in Firebase Auth, captured once at
  /// [initState] so it remains stable across rebuilds.
  late final String _currentEmail;

  // ── Controllers ────────────────────────────────────────────────────────────

  /// Read-only display controller for the greyed-out current-email field.
  late final TextEditingController _currentEmailController;

  /// Collects the user's current password for re-authentication (Step 1).
  late final TextEditingController _passwordController;

  /// Collects the desired new email address (Step 2).
  late final TextEditingController _newEmailController;

  // ── Constants ──────────────────────────────────────────────────────────────

  /// RFC-5322-inspired pattern used to validate the new email address locally
  /// before making any Firebase calls.
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // ── Life-cycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    _currentEmailController = TextEditingController(text: _currentEmail);
    _passwordController = TextEditingController();
    _newEmailController = TextEditingController();
  }

  @override
  void dispose() {
    _currentEmailController.dispose();
    _passwordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  // ── Step 1 Logic ───────────────────────────────────────────────────────────

  /// Re-authenticates the signed-in user with [EmailAuthProvider.credential].
  ///
  /// On **success** advances to Step 2.
  /// On **wrong-password / invalid-credential** sets [_showForgotLink] = true
  /// and shows a SnackBar.
  /// All other [FirebaseAuthException]s surface their message via SnackBar.
  Future<void> _verifyPassword() async {
    final String password = _passwordController.text;

    if (password.isEmpty) {
      _showSnackBar('Please enter your current password.');
      return;
    }

    setState(() => _loading = true);

    try {
      final User user = FirebaseAuth.instance.currentUser!;
      final AuthCredential credential = EmailAuthProvider.credential(
        email: _currentEmail,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      if (!mounted) return;

      /// Advance to the new-email entry phase.
      setState(() {
        _currentStep = 2;
        _showForgotLink = false;
        _loading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        /// Reveal the forgot-password escape-hatch.
        setState(() {
          _showForgotLink = true;
          _loading = false;
        });
        _showSnackBar('Incorrect password.');
      } else {
        setState(() => _loading = false);
        _showSnackBar(e.message ?? 'Verification failed. Please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('Something went wrong. Please try again.');
    }
  }

  /// Sends a password-reset email to [_currentEmail] directly via Firebase,
  /// bypassing the need to navigate away.  Shows a confirmation SnackBar.
  Future<void> _handleForgotPassword() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _currentEmail,
      );
      if (!mounted) return;
      _showSnackBar('Password reset link sent to $_currentEmail.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message ?? 'Failed to send reset email.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Failed to send reset email. Please try again.');
    }
  }

  // ── Step 2 Logic ───────────────────────────────────────────────────────────

  /// Validates the new email locally, then calls [User.verifyBeforeUpdateEmail].
  ///
  /// Firebase sends a confirmation link to the **new** address.  [currentUser.email]
  /// is NOT updated locally — the change only propagates after the user clicks
  /// the link, at which point Firebase Auth refreshes the token automatically.
  Future<void> _sendVerificationLink() async {
    final String newEmail = _newEmailController.text.trim();

    if (newEmail.isEmpty) {
      _showSnackBar('Please enter a new email address.');
      return;
    }

    if (!_emailRegex.hasMatch(newEmail)) {
      _showSnackBar('Please enter a valid email address.');
      return;
    }

    if (newEmail == _currentEmail) {
      _showSnackBar('New email must be different from your current one.');
      return;
    }

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.currentUser!
          .verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      setState(() => _loading = false);

      /// Show the success sheet; pop back to CredentialsScreen on dismiss.
      await _showSuccessSheet(newEmail);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar(e.message ?? 'Could not send verification link.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('Something went wrong. Please try again.');
    }
  }

  /// Presents a bottom-sheet confirming the verification email was dispatched.
  ///
  /// [isDismissible] and [enableDrag] are both false so the user must
  /// consciously tap "Got It" — this avoids accidental dismissal before they
  /// have read the instructions.  After the sheet closes, [Navigator.pop]
  /// returns the user to [CredentialsScreen].
  Future<void> _showSuccessSheet(String newEmail) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusXXL),
        ),
      ),
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Success icon badge.
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.statusSuccess.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.statusSuccess,
                  size: 34,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              Text(
                'Verification Link Sent!',
                style: AppTextStyles.headingLarge(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'We\'ve sent a confirmation link to\n$newEmail\n\n'
                'Your email will update only after you click the link '
                'in your new inbox.',
                style: AppTextStyles.bodyMedium(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got It'),
                ),
              ),
            ],
          ),
        );
      },
    );

    /// After the sheet is dismissed, return to CredentialsScreen.
    if (mounted) Navigator.of(context).pop();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.backgroundTertiary,
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Change Email'),
      body: SafeArea(
        /// Block all taps while a Firebase operation is in flight.
        child: AbsorbPointer(
          absorbing: _loading,
          child: Column(
            children: [
              /// Scrollable content area switches between the two step widgets.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
                ),
              ),

              /// Fixed bottom action button — label changes per step.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : (_currentStep == 1
                            ? _verifyPassword
                            : _sendVerificationLink),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.backgroundQuaternary,
                      disabledForegroundColor: AppColors.textTertiary,
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
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == 1
                                ? 'Verify Password'
                                : 'Send Verification Link',
                            style: AppTextStyles.headingSmall(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step Widgets ───────────────────────────────────────────────────────────

  /// Step 1: Displays the current (read-only) email and collects the current
  /// password to re-authenticate the user via Firebase before allowing changes.
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /// Read-only display of the currently registered email.
        const FieldLabel('Current Email'),
        TextField(
          controller: _currentEmailController,
          enabled: false,
          keyboardType: TextInputType.emailAddress,
          style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
        ),

        const SizedBox(height: AppSpacing.lg),

        /// Password field used purely for re-authentication.
        const FieldLabel('Current Password'),
        TextField(
          controller: _passwordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.visiblePassword,
          onSubmitted: (_) {
            if (!_loading) _verifyPassword();
          },
          decoration: const InputDecoration(
            hintText: 'Enter your current password',
          ),
          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
        ),

        /// The forgot-password escape-hatch — only rendered after a failed
        /// re-authentication attempt so it does not clutter the initial view.
        if (_showForgotLink) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
              ),
              child: Text(
                'Forgot Password? Reset it here.',
                style: AppTextStyles.bodySmall(
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Step 2: Collects the new email address.  Clearly states that the change
  /// only applies after the user clicks the verification link in their new inbox.
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('New Email'),
        TextField(
          controller: _newEmailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_loading) _sendVerificationLink();
          },
          decoration: const InputDecoration(
            hintText: 'Enter your new email address',
          ),
          style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
        ),

        const SizedBox(height: AppSpacing.md),

        /// Informational note — explicitly manages user expectations around
        /// the deferred Firebase email-update behaviour.
        Text(
          'A verification link will be sent to your new address. '
          'Your email only updates after you click the link.',
          style: AppTextStyles.bodySmall(),
        ),
      ],
    );
  }
}
