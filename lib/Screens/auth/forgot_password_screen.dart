import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_gradients.dart';
import 'login_screen.dart';

/// FORGOT PASSWORD SCREEN
///
/// Complete forgot password reset flow with:
/// - Email confirmation input
/// - "Send Reset Link" button
/// - Placeholder function to send password reset email
/// - After reset, user can return to login with new password
/// - Success/Error feedback with dialogs

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late TextEditingController _emailController;
  bool _isResetEmailSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    final email = _emailController.text.trim();

    // Validate email
    if (email.isEmpty) {
      _showErrorDialog('Please enter your email address.');
      return;
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      _showErrorDialog('Please enter a valid email address.');
      return;
    }

    // Call Firebase to send password reset email
    final authProvider = context.read<BrutlAuthProvider>();

    try {
      // Firebase Auth: Send password reset email
      // This is a placeholder - actual implementation uses Firebase
      await authProvider.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      setState(() {
        _isResetEmailSent = true;
      });

      _showSuccessDialog(
        'Reset Link Sent!',
        'We\'ve sent a password reset link to $email.\n\n'
            'Check your email and click the link to create a new password.\n\n'
            'Once you\'ve reset your password, you can log back in.\n\n'
            'Note: If you don\'t see the email, check your spam folder or try again.',
      );
    } catch (e) {
      _showErrorDialog('Failed to send reset link. Please try again.');
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to login
            },
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.backgroundPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _isResetEmailSent ? _buildSuccessState() : _buildResetForm(),
        ),
      ),
    );
  }

  /// FORGOT PASSWORD FORM
  ///
  /// Asks user to confirm their email address and provides
  /// a button to send password reset link
  Widget _buildResetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          'Forgot Your Password?',
          style: AppTextStyles.displayMedium(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'No worries! Enter your email and we\'ll send you a link to reset your password.',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Check your email for a password reset link. '
                  'The link will expire in 24 hours.',
                  style: AppTextStyles.labelSmall(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Email input
        _buildEmailInput(),
        const SizedBox(height: 28),

        // Send Reset Link button
        _buildSendResetLinkButton(),
      ],
    );
  }

  /// SUCCESS STATE
  ///
  /// Shown after the reset email has been sent successfully
  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.check_circle,
            color: AppColors.accentPrimary,
            size: 48,
          ),
        ),

        // Success message
        Text(
          'Check Your Email',
          style: AppTextStyles.displayMedium(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ve sent a password reset link to ${_emailController.text}',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Instructions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What to do next:',
                style: AppTextStyles.headingSmall(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Check your email inbox\n'
                '2. Click on the password reset link\n'
                '3. Create your new password\n'
                '4. Return here and log in with your new password',
                style: AppTextStyles.bodySmall(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Back to login button
        _BrutlGradientButton(
          label: 'Back to Login',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(height: 12),

        // Didn't receive email link
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _isResetEmailSent = false;
              });
              _emailController.clear();
            },
            child: Text(
              'Didn\'t receive the email? Try again',
              style: AppTextStyles.labelLarge(
                color: AppColors.accentPrimary,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }

  /// EMAIL INPUT FIELD
  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter your registered email',
              hintStyle: AppTextStyles.bodyLarge(color: AppColors.textTertiary),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.textTertiary,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderDefault, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderDefault, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// SEND RESET LINK BUTTON
  Widget _buildSendResetLinkButton() {
    return Consumer<BrutlAuthProvider>(
      builder: (context, authProvider, _) {
        return Opacity(
          opacity: authProvider.isLoading ? 0.55 : 1,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: AppGradients.accentGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40FF3D00),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: authProvider.isLoading ? null : _handleSendResetLink,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'Send Reset Link',
                          style: AppTextStyles.headingSmall(
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrutlGradientButton extends StatelessWidget {
  const _BrutlGradientButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppGradients.accentGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40FF3D00),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.headingSmall(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
