import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';
import '../../widgets/password_input_field.dart';

/// SIGN-UP SCREEN
///
/// Complete sign-up flow with:
/// - Email input
/// - Password input with eye icon toggle
/// - Confirm password input with eye icon toggle
/// - Real-time validation for password rules
/// - Dynamic "Sign Up" button (enabled only when all rules are met)
/// - Professional UI with smooth animations

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late AuthValidationProvider _validationProvider;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    _validationProvider = context.read<AuthValidationProvider>();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

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

    // All validations are already checked by the button being enabled,
    // but we verify once more for security
    if (!_validationProvider.isSixCharactersValid) {
      _showErrorDialog('Password must be at least 6 characters.');
      return;
    }

    if (!_validationProvider.hasSpecialCharacter) {
      _showErrorDialog('Password must contain at least one special character.');
      return;
    }

    if (!_validationProvider.doPasswordsMatch) {
      _showErrorDialog('Passwords do not match.');
      return;
    }

    // Call the auth provider to register
    final authProvider = context.read<BrutlAuthProvider>();
    final success = await authProvider.signUpWithEmail(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      // Sign-up successful, navigate to next screen or home
      _showSuccessDialog('Account created successfully!');
      // Clear form
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _validationProvider.resetValidationState();
    } else {
      _showErrorDialog(
        authProvider.errorMessage ?? 'Sign-up failed. Please try again.',
      );
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
        title: const Text('Oops!'),
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF9FAFB),
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Consumer<AuthValidationProvider>(
            builder: (context, validationProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Text(
                    'Join Brutl Today',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your account to get started with your fitness journey',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 28),

                  // ============ EMAIL INPUT ============
                  _buildEmailInput(),
                  const SizedBox(height: 20),

                  // ============ PASSWORD INPUT WITH EYE ICON ============
                  PasswordInputField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Enter your password',
                    isVisible: validationProvider.isPasswordVisible,
                    onVisibilityToggle: (value) {
                      validationProvider.togglePasswordVisibility();
                    },
                    onChanged: (value) {
                      validationProvider.updatePassword(value);
                    },
                  ),
                  const SizedBox(height: 12),

                  // ============ GREEN TEXT VALIDATION ============
                  // PASSWORD INSTRUCTION RULES: Display below first password box
                  // These rules change color to GREEN when requirements are met
                  _buildPasswordRulesDisplay(validationProvider),
                  const SizedBox(height: 20),

                  // ============ CONFIRM PASSWORD INPUT WITH EYE ICON ============
                  PasswordInputField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hintText: 'Re-enter your password',
                    isVisible: validationProvider.isConfirmPasswordVisible,
                    onVisibilityToggle: (value) {
                      validationProvider.toggleConfirmPasswordVisibility();
                    },
                    onChanged: (value) {
                      validationProvider.updateConfirmPassword(value);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Password match indicator
                  if (_passwordController.text.isNotEmpty &&
                      _confirmPasswordController.text.isNotEmpty)
                    _buildPasswordMatchIndicator(validationProvider),
                  const SizedBox(height: 28),

                  // ============ DISABLED BUTTON LOGIC ============
                  // SIGN-UP BUTTON: Only enabled when ALL conditions are met
                  // 1. Password has 6+ characters
                  // 2. Password has special character
                  // 3. Both password fields match
                  _buildSignUpButton(validationProvider),
                  const SizedBox(height: 16),

                  // Login link
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        children: [
                          TextSpan(
                            text: 'Login',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: null, // Navigate to login screen
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// EMAIL INPUT FIELD
  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
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
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFD1D5DB)),
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

  /// GREEN TEXT VALIDATION FEATURE
  ///
  /// Displays password rules below the first password input.
  /// Rules dynamically change color based on validation:
  /// - GREY (default): Rule not met
  /// - GREEN: Rule met and active
  ///
  /// This provides real-time visual feedback to the user
  Widget _buildPasswordRulesDisplay(AuthValidationProvider validationProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rule 1: At least 6 characters
          // GREEN TEXT when valid, GREY when invalid
          Row(
            children: [
              Icon(
                validationProvider.isSixCharactersValid
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: validationProvider.isSixCharactersValid
                    ? const Color(0xFF10B981) // Green checkmark
                    : const Color(0xFF9CA3AF), // Grey unchecked
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Password should be at least 6 characters.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: validationProvider.isSixCharactersValid
                        ? const Color(0xFF10B981) // Green text when valid
                        : const Color(0xFF6B7280), // Grey text when invalid
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rule 2: At least one special character
          // GREEN TEXT when valid, GREY when invalid
          Row(
            children: [
              Icon(
                validationProvider.hasSpecialCharacter
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: validationProvider.hasSpecialCharacter
                    ? const Color(0xFF10B981) // Green checkmark
                    : const Color(0xFF9CA3AF), // Grey unchecked
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Include at least one special character (e.g., @, #, \$, %, etc.).',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: validationProvider.hasSpecialCharacter
                        ? const Color(0xFF10B981) // Green text when valid
                        : const Color(0xFF6B7280), // Grey text when invalid
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Password match indicator
  Widget _buildPasswordMatchIndicator(
    AuthValidationProvider validationProvider,
  ) {
    return Row(
      children: [
        Icon(
          validationProvider.doPasswordsMatch
              ? Icons.check_circle
              : Icons.cancel,
          size: 16,
          color: validationProvider.doPasswordsMatch
              ? const Color(0xFF10B981)
              : const Color(0xFFF87171),
        ),
        const SizedBox(width: 8),
        Text(
          validationProvider.doPasswordsMatch
              ? 'Passwords match'
              : 'Passwords do not match',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: validationProvider.doPasswordsMatch
                ? const Color(0xFF10B981)
                : const Color(0xFFF87171),
          ),
        ),
      ],
    );
  }

  /// DISABLED BUTTON LOGIC
  ///
  /// Sign-Up button state depends on:
  /// 1. Rule 1 met: 6+ characters
  /// 2. Rule 2 met: Special character
  /// 3. Passwords match
  ///
  /// Button is disabled (faded grey) until ALL conditions are true,
  /// then it becomes active (primary color) and clickable
  Widget _buildSignUpButton(AuthValidationProvider validationProvider) {
    final isEnabled = validationProvider.isSignUpButtonEnabled;

    return Consumer<BrutlAuthProvider>(
      builder: (context, authProvider, _) {
        return ElevatedButton(
          onPressed: isEnabled && !authProvider.isLoading
              ? _handleSignUp
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isEnabled
                ? const Color(0xFF6366F1) // Active primary color
                : const Color(0xFFE5E7EB), // Faded light grey when disabled
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: isEnabled ? 2 : 0,
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
              : Text(
                  'Sign Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isEnabled
                        ? Colors.white
                        : const Color(0xFF9CA3AF), // Grey text when disabled
                  ),
                ),
        );
      },
    );
  }
}
