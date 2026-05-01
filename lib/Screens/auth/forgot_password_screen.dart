import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
            'Once you\'ve reset your password, you can log back in.',
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
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF9FAFB),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF9FAFB),
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
        const Text(
          'Forgot Your Password?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'No worries! Enter your email and we\'ll send you a link to reset your password.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
        ),
        const SizedBox(height: 28),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Check your email for a password reset link. '
                  'The link will expire in 24 hours.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
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
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.check_circle,
            color: Color(0xFF10B981),
            size: 48,
          ),
        ),

        // Success message
        const Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We\'ve sent a password reset link to ${_emailController.text}',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Instructions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What to do next:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF78350F),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Check your email inbox\n'
                '2. Click on the password reset link\n'
                '3. Create your new password\n'
                '4. Return here and log in with your new password',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF92400E),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Back to login button
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          child: const Text(
            'Back to Login',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
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
            child: const Text(
              'Didn\'t receive the email? Try again',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w500,
              ),
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
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Enter your registered email',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFD1D5DB)),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Color(0xFF9CA3AF),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: const Color(0xFFFFFFFF),
          ),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
        ),
      ],
    );
  }

  /// SEND RESET LINK BUTTON
  Widget _buildSendResetLinkButton() {
    return Consumer<BrutlAuthProvider>(
      builder: (context, authProvider, _) {
        return ElevatedButton(
          onPressed: authProvider.isLoading ? null : _handleSendResetLink,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          child: authProvider.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF6366F1),
                    ),
                  ),
                )
              : const Text(
                  'Send Reset Link',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        );
      },
    );
  }
}
