import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';
import '../../widgets/password_input_field.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// LOGIN SCREEN
///
/// Complete login flow with:
/// - Email input
/// - Password input with eye icon toggle
/// - Error handling with dynamic "Forgot Password?" link
/// - The "Forgot Password?" link appears in RED when wrong password error occurs
/// - Professional UI with smooth animations

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late AuthValidationProvider _validationProvider;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    _validationProvider = context.read<AuthValidationProvider>();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validate email
    if (email.isEmpty) {
      _validationProvider.clearLoginError();
      _showErrorDialog('Please enter your email address.');
      return;
    }

    // Validate password
    if (password.isEmpty) {
      _validationProvider.clearLoginError();
      _showErrorDialog('Please enter your password.');
      return;
    }

    // Call the auth provider to login
    final authProvider = context.read<BrutlAuthProvider>();
    final success = await authProvider.signInWithEmail(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      // Login successful, navigate to home screen
      _validationProvider.clearLoginError();
      // The app will automatically navigate based on auth state
    } else {
      // Login failed - show error and set "Forgot Password?" link to visible
      final errorMessage =
          authProvider.errorMessage ?? 'Login failed. Please try again.';
      final isWrongPasswordError = _isWrongPasswordError(errorMessage);

      // Set login error to trigger "Forgot Password?" link visibility
      _validationProvider.setLoginError(
        errorMessage,
        showForgotPasswordLink: isWrongPasswordError,
      );
      _showErrorDialog(errorMessage);
    }
  }

  bool _isWrongPasswordError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('wrong password') ||
        normalized.contains('incorrect credentials') ||
        normalized.contains('invalid credential');
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Error'),
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
        title: const Text('Login'),
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
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login to your account to continue your fitness journey',
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
                    isVisible: validationProvider.isLoginPasswordVisible,
                    onVisibilityToggle: (value) {
                      validationProvider.toggleLoginPasswordVisibility();
                    },
                    onChanged: (value) {
                      // Keep login error state clean while user edits.
                      validationProvider.clearLoginError();
                    },
                  ),
                  const SizedBox(height: 12),

                  // ============ DYNAMIC "FORGOT PASSWORD?" LINK ============
                  // ERROR HANDLING: Link appears in RED only when login error occurs
                  // This link appears below the password box when wrong password error happens
                  if (validationProvider.showForgotPasswordLink)
                    _buildForgotPasswordLink(),

                  const SizedBox(height: 28),

                  // ============ LOGIN BUTTON ============
                  _buildLoginButton(),
                  const SizedBox(height: 16),

                  // Sign up link
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  /// DYNAMIC "FORGOT PASSWORD?" LINK
  ///
  /// ERROR HANDLING: This link only appears when a wrong password error occurs.
  /// It's displayed in RED color to grab user attention.
  /// Clicking it navigates to the forgot password reset screen.
  Widget _buildForgotPasswordLink() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: const Color(0xFFF87171), // Red icon
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Forgot Password? Click here to reset',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFF87171), // Red text
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// LOGIN BUTTON
  Widget _buildLoginButton() {
    return Consumer<BrutlAuthProvider>(
      builder: (context, authProvider, _) {
        return ElevatedButton(
          onPressed: authProvider.isLoading ? null : _handleLogin,
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
                  'Login',
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
