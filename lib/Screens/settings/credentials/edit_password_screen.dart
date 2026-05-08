import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/edit_screen_scaffold.dart';
import '../widgets/settings_widgets.dart';

/// Password-change screen.
///
/// Presents three password fields, each with an independent eye-icon toggle:
///
/// 1. **Current Password** — used to re-authenticate the user before any
///    change is applied.  A "Forgot current password?" link immediately below
///    this field sends a Firebase reset email to [currentUser.email].
/// 2. **New Password** — the desired replacement credential (min 6 chars).
/// 3. **Confirm New Password** — must match [New Password] exactly.
///
/// Update sequence:
/// 1. Client-side validation (match + minimum length).
/// 2. [User.reauthenticateWithCredential] — catches `wrong-password` /
///    `invalid-credential` before attempting the actual update.
/// 3. [User.updatePassword] — applies the new credential.
/// 4. Green SnackBar + [Navigator.pop] on success.
///
/// **Firestore Note:** Changing a password does not affect any field in the
/// Firestore `users` document, so no Firestore writes are performed here.
///
/// **Session Note:** Firebase does NOT sign the user out after a password
/// update on the current device.  No manual sign-out is triggered.
class EditPasswordScreen extends StatefulWidget {
  const EditPasswordScreen({super.key});

  @override
  State<EditPasswordScreen> createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────

  /// Collects the existing password used to re-authenticate.
  final TextEditingController _currentPasswordController =
      TextEditingController();

  /// Collects the desired new password.
  final TextEditingController _newPasswordController = TextEditingController();

  /// Must match [_newPasswordController] before submission.
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ── Visibility toggles ─────────────────────────────────────────────────────
  /// Each field owns its own boolean so toggling one does not affect the others.

  /// When `true`, Current Password field shows plain text.
  bool _showCurrentPassword = false;

  /// When `true`, New Password field shows plain text.
  bool _showNewPassword = false;

  /// When `true`, Confirm New Password field shows plain text.
  bool _showConfirmPassword = false;

  // ── Loading guard ──────────────────────────────────────────────────────────

  /// Prevents double-submission.  When `true`, the action button renders a
  /// spinner and [AbsorbPointer] blocks all taps on the form.
  bool _loading = false;

  // ── Life-cycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Update Logic ───────────────────────────────────────────────────────────

  /// Validates inputs, re-authenticates, then calls [User.updatePassword].
  Future<void> _updatePassword() async {
    final String currentPw = _currentPasswordController.text;
    final String newPw = _newPasswordController.text;
    final String confirmPw = _confirmPasswordController.text;

    /// Validation 1 — fields must not be empty.
    if (currentPw.isEmpty) {
      _showSnackBar('Please enter your current password.');
      return;
    }

    /// Validation 2 — new passwords must match.
    if (newPw != confirmPw) {
      _showSnackBar('Passwords do not match.');
      return;
    }

    /// Validation 3 — minimum length enforced by Firebase (6 chars).
    if (newPw.length < 6) {
      _showSnackBar('New password must be at least 6 characters.');
      return;
    }

    setState(() => _loading = true);

    try {
      final User user = FirebaseAuth.instance.currentUser!;

      /// Re-authenticate to confirm the user knows the current credential
      /// before we allow a sensitive change.
      final AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPw,
      );
      await user.reauthenticateWithCredential(credential);

      /// Apply the new password.  Firebase does not sign the user out on the
      /// current device after this call.
      await user.updatePassword(newPw);

      if (!mounted) return;
      setState(() => _loading = false);

      /// Green SnackBar confirms success before navigating away.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Password successfully updated.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.statusSuccess,
          ),
        );

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showSnackBar('Incorrect current password.');
      } else {
        _showSnackBar(e.message ?? 'Update failed. Please try again.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('Something went wrong. Please try again.');
    }
  }

  /// Sends a password-reset email to the currently registered address so the
  /// user can regain access if they have forgotten their current password.
  Future<void> _sendForgotPasswordEmail() async {
    final String? email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showSnackBar('Reset link sent to your email.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message ?? 'Failed to send reset email.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Failed to send reset email. Please try again.');
    }
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
      appBar: buildSettingsAppBar(context, 'Change Password'),
      body: SafeArea(
        /// Block all form interactions while a Firebase call is in flight.
        child: AbsorbPointer(
          absorbing: _loading,
          child: Column(
            children: [
              /// Scrollable form content.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── FIELD 1: CURRENT PASSWORD ─────────────────────────
                      const FieldLabel('Current Password'),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: !_showCurrentPassword,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter your current password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showCurrentPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            /// Toggle [_showCurrentPassword] independently of
                            /// the other two visibility booleans.
                            onPressed: () => setState(
                              () => _showCurrentPassword =
                                  !_showCurrentPassword,
                            ),
                          ),
                        ),
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.textPrimary,
                        ),
                      ),

                      // ── FORGOT PASSWORD LINK ──────────────────────────────
                      /// Always visible below Field 1, right-aligned.
                      /// Directly triggers a Firebase reset email so the user
                      /// does not have to leave this screen.
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _loading ? null : _sendForgotPasswordEmail,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.xs,
                            ),
                          ),
                          child: Text(
                            'Forgot current password?',
                            style: AppTextStyles.bodySmall(
                              color: AppColors.accentPrimary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // ── FIELD 2: NEW PASSWORD ─────────────────────────────
                      const FieldLabel('New Password'),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_showNewPassword,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.visiblePassword,
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            /// Toggle [_showNewPassword] independently.
                            onPressed: () => setState(
                              () => _showNewPassword = !_showNewPassword,
                            ),
                          ),
                        ),
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── FIELD 3: CONFIRM NEW PASSWORD ─────────────────────
                      const FieldLabel('Confirm New Password'),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.visiblePassword,
                        onSubmitted: (_) {
                          if (!_loading) _updatePassword();
                        },
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            /// Toggle [_showConfirmPassword] independently.
                            onPressed: () => setState(
                              () => _showConfirmPassword =
                                  !_showConfirmPassword,
                            ),
                          ),
                        ),
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── ACTION BUTTON ─────────────────────────────────────────────
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
                    onPressed: _loading ? null : _updatePassword,
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
                            'Update Password',
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
}
