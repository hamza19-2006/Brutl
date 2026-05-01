import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';
import '../../widgets/password_input_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

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
    final validation = context.read<AuthValidationProvider>();
    final authProvider = context.read<BrutlAuthProvider>();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showDialog('Please enter your email address.', isError: true);
      return;
    }

    if (!_isValidEmail(email)) {
      _showDialog('Please enter a valid email address.', isError: true);
      return;
    }

    if (!validation.isSignUpButtonEnabled) {
      _showDialog('Please satisfy all password rules first.', isError: true);
      return;
    }

    final success = await authProvider.signUpWithEmail(
      email: email,
      password: password,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _showDialog(
        'Account created successfully. Welcome to Brutl!',
        isError: false,
      );
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      validation.resetValidationState();
      return;
    }

    _showDialog(
      authProvider.errorMessage ?? 'Sign-up failed. Please try again.',
      isError: true,
    );
  }

  Future<void> _handleGoogleSignUp() async {
    final authProvider = context.read<BrutlAuthProvider>();
    final success = await authProvider.signInWithGoogle();

    if (!mounted || success) {
      return;
    }

    _showDialog(
      authProvider.errorMessage ?? 'Google sign-up failed. Please try again.',
      isError: true,
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _showDialog(String message, {required bool isError}) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: BorderSide(
            color: isError ? AppColors.statusError : AppColors.borderDefault,
          ),
        ),
        title: Text(
          isError ? 'Sign Up Error' : 'Success',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Consumer2<AuthValidationProvider, BrutlAuthProvider>(
            builder: (context, validation, authProvider, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JOIN BRUTL', style: AppTextStyles.accentLabel()),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Build your strongest self.',
                    style: AppTextStyles.displayMedium(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Create your account with Email or continue with Google.',
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
                          hintText: 'Create your password',
                          isVisible: validation.isPasswordVisible,
                          onVisibilityToggle: (_) {
                            validation.togglePasswordVisibility();
                          },
                          onChanged: validation.updatePassword,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildPasswordRulesDisplay(validation),
                        const SizedBox(height: AppSpacing.lg),
                        PasswordInputField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hintText: 'Re-enter your password',
                          isVisible: validation.isConfirmPasswordVisible,
                          onVisibilityToggle: (_) {
                            validation.toggleConfirmPasswordVisibility();
                          },
                          onChanged: validation.updateConfirmPassword,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_passwordController.text.isNotEmpty ||
                            _confirmPasswordController.text.isNotEmpty)
                          _buildPasswordMatchIndicator(validation),
                        const SizedBox(height: AppSpacing.xl),
                        _BrutlGradientButton(
                          label: authProvider.isLoading
                              ? 'Creating Account...'
                              : 'Sign Up with Email',
                          isLoading: authProvider.isLoading,
                          onPressed:
                              validation.isSignUpButtonEnabled &&
                                  !authProvider.isLoading
                              ? _handleSignUp
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildOrDivider(),
                        const SizedBox(height: AppSpacing.lg),
                        _BrutlSecondaryButton(
                          label: 'Sign Up with Google',
                          iconAssetPath: 'assets/Images/google_logo.jpg',
                          onPressed: authProvider.isLoading
                              ? null
                              : _handleGoogleSignUp,
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
                          'Already have an account? ',
                          style: AppTextStyles.bodySmall(),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Sign In',
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

  Widget _buildPasswordRulesDisplay(AuthValidationProvider validation) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundQuaternary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRuleItem(
            isValid: validation.isSixCharactersValid,
            text: 'Password should be at least 6 characters.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRuleItem(
            isValid: validation.hasSpecialCharacter,
            text: 'Include at least one special character.',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem({required bool isValid, required String text}) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isValid ? AppColors.statusSuccess : AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelLarge(
              color: isValid
                  ? AppColors.statusSuccess
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordMatchIndicator(AuthValidationProvider validation) {
    return Row(
      children: [
        Icon(
          validation.doPasswordsMatch ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: validation.doPasswordsMatch
              ? AppColors.statusSuccess
              : AppColors.statusError,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          validation.doPasswordsMatch
              ? 'Passwords match'
              : 'Passwords do not match',
          style: AppTextStyles.labelLarge(
            color: validation.doPasswordsMatch
                ? AppColors.statusSuccess
                : AppColors.statusError,
          ),
        ),
      ],
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
  });

  final String label;
  final String iconAssetPath;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundTertiary,
          side: const BorderSide(color: AppColors.borderDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppSpacing.borderRadiusMedium + 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconAssetPath,
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.headingSmall(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
