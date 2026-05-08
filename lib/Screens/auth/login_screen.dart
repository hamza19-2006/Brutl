import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';
import '../../providers/brutl_user_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/password_input_field.dart';
import '../home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

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

  /// BUG 2 FIX: After FirebaseAuth confirms the sign-in, both WorkoutProvider
  /// and BrutlUserProvider are awaited before navigating. This ensures the
  /// Home screen renders with real Firestore data on the very first frame
  /// instead of briefly showing hardcoded defaults (2000 kcal, 10000 steps).
  Future<void> _handleLogin() async {
    if (_isEmailLoading || _isGoogleLoading) {
      return;
    }

    final validation = context.read<AuthValidationProvider>();
    final authProvider = context.read<BrutlAuthProvider>();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      validation.clearLoginError();
      _showErrorDialog('Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      validation.clearLoginError();
      _showErrorDialog('Please enter your password.');
      return;
    }

    setState(() {
      _isEmailLoading = true;
    });

    try {
      final success = await authProvider.signInWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      if (success) {
        validation.clearLoginError();

        // BUG 2 FIX: Pre-fetch real user data from Firestore into both
        // providers BEFORE navigating so the Home screen never shows defaults.
        await context.read<WorkoutProvider>().loadUserData();
        if (!mounted) return;
        await context.read<BrutlUserProvider>().bindToCurrentUser();
        if (!mounted) return;

        // Navigate only after providers are hydrated with real data.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }

      final errorMessage =
          authProvider.errorMessage ?? 'Login failed. Please try again.';
      final isWrongPasswordError = _isWrongPasswordError(errorMessage);

      validation.setLoginError(
        errorMessage,
        showForgotPasswordLink: isWrongPasswordError,
      );
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isEmailLoading || _isGoogleLoading) {
      return;
    }

    final authProvider = context.read<BrutlAuthProvider>();
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final result = await authProvider.signInWithGoogleWithResult();

      if (!mounted) {
        return;
      }

      if (result.success) {
        // Keep loader active during navigation — don't reset it here
        await _navigateAfterGoogleAuth(isNewUser: result.isNewUser);
        return;
      }

      if (!result.wasCancelled) {
        _showErrorSnackBar(
          result.errorMessage ??
              authProvider.errorMessage ??
              'Google sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted && !_isGoogleLoading) {
        // Only reset if we haven't already navigated
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  Future<void> _navigateAfterGoogleAuth({required bool isNewUser}) async {
    final destination = isNewUser
        ? const OnboardingScreen()
        : const HomeScreen();

    // Navigate while loader is still active
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => destination),
        (route) => false,
      );
    }
  }

  bool _isWrongPasswordError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('wrong password') ||
        normalized.contains('incorrect credentials') ||
        normalized.contains('invalid credential');
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.borderDefault),
        ),
        title: Text(
          'Login Error',
          style: AppTextStyles.headingMedium(color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In'), centerTitle: false),
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Consumer2<AuthValidationProvider, BrutlAuthProvider>(
            builder: (context, validation, _unused, _unused2) {
              final isAnyLoading = _isEmailLoading || _isGoogleLoading;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WELCOME BACK', style: AppTextStyles.accentLabel()),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Train hard. Track harder.',
                    style: AppTextStyles.displayMedium(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sign in with Email or continue with Google.',
                    style: AppTextStyles.bodyMedium(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusXL,
                      ),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEmailInput(),
                        const SizedBox(height: AppSpacing.lg),
                        PasswordInputField(
                          controller: _passwordController,
                          label: 'Password',
                          hintText: 'Enter your password',
                          isVisible: validation.isLoginPasswordVisible,
                          onVisibilityToggle: (_) {
                            validation.toggleLoginPasswordVisibility();
                          },
                          onChanged: (_) => validation.clearLoginError(),
                          textInputAction: TextInputAction.done,
                        ),
                        if (validation.showForgotPasswordLink) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _buildForgotPasswordLink(),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        _BrutlGradientButton(
                          label: _isEmailLoading
                              ? 'Signing In...'
                              : 'Sign In with Email',
                          isLoading: _isEmailLoading,
                          onPressed: isAnyLoading ? null : _handleLogin,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildOrDivider(),
                        const SizedBox(height: AppSpacing.lg),
                        _BrutlSecondaryButton(
                          label: 'Sign In with Google',
                          iconAssetPath: 'assets/Images/google_logo.jpg',
                          isLoading: _isGoogleLoading,
                          onPressed: isAnyLoading ? null : _handleGoogleSignIn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: AppTextStyles.bodySmall(),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: AppTextStyles.headingSmall(
                              color: AppColors.accentPrimary,
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

  Widget _buildEmailInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Enter your email'),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordLink() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
        );
      },
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: AppColors.statusError,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Forgot Password? Reset it now',
              style: AppTextStyles.labelLarge(
                color: AppColors.statusError,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.borderSubtle, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('OR', style: AppTextStyles.labelSmall()),
        ),
        const Expanded(
          child: Divider(color: AppColors.borderSubtle, thickness: 1),
        ),
      ],
    );
  }
}

class _BrutlGradientButton extends StatelessWidget {
  const _BrutlGradientButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppGradients.accentGradient,
          borderRadius: BorderRadius.circular(
            AppSpacing.borderRadiusMedium + 2,
          ),
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
            borderRadius: BorderRadius.circular(
              AppSpacing.borderRadiusMedium + 2,
            ),
            onTap: onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: AppTextStyles.headingSmall(
                        color: AppColors.textPrimary,
                      ).copyWith(letterSpacing: 0.5),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrutlSecondaryButton extends StatelessWidget {
  const _BrutlSecondaryButton({
    required this.label,
    required this.iconAssetPath,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final String iconAssetPath;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppSpacing.borderRadiusMedium + 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                ),
              )
            else ...[
              Image.asset(
                iconAssetPath,
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.g_mobiledata,
                  size: 22,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              isLoading ? 'Signing In...' : label,
              style: AppTextStyles.headingSmall(color: const Color(0xFF1A1A1A)),
            ),
          ],
        ),
      ),
    );
  }
}
