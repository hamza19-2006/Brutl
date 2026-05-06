import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_validation_provider.dart';
import '../home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const String _otpWebhookUrl =
      'https://n8n.hamza-systems.tech/webhook/otp';
  static const String _verifyOtpWebhookUrl =
      'https://n8n.hamza-systems.tech/webhook/verify-otp';

  late final TextEditingController _emailController;
  late final TextEditingController _verificationCodeController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _showPasswordRules = false;
  bool _isOtpSending = false;
  bool _isOtpVerified = false;
  bool _isOtpVerifying = false;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  static const int _maxOtpAttempts = 3;
  int _otpFailedAttempts = 0;
  DateTime? _otpLockedUntil;

  String? _verifiedOtpEmail;
  String? _verifiedOtpCode;
  String? _lastAutoVerifiedCode;
  final FocusNode _passwordFocusNode = FocusNode();

  bool get _isAnyLoading =>
      _isOtpSending || _isEmailLoading || _isGoogleLoading || _isOtpVerifying;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _verificationCodeController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _emailController.addListener(_invalidateOtpVerificationIfNeeded);
    _verificationCodeController.addListener(_invalidateOtpVerificationIfNeeded);
    _verificationCodeController.addListener(_handleOtpAutoVerify);

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setState(() {
          _showPasswordRules = true;
        });
        if (_verificationCodeController.text.trim().isNotEmpty &&
            !_isOtpVerified) {
          unawaited(verifyOtp(showSuccessMessage: false));
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_invalidateOtpVerificationIfNeeded);
    _verificationCodeController.removeListener(
      _invalidateOtpVerificationIfNeeded,
    );
    _verificationCodeController.removeListener(_handleOtpAutoVerify);
    _emailController.dispose();
    _verificationCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_isAnyLoading) {
      return;
    }

    final validation = context.read<AuthValidationProvider>();
    final authProvider = context.read<BrutlAuthProvider>();
    final email = _emailController.text.trim().toLowerCase();
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

    final isOtpValid = await verifyOtp(showSuccessMessage: false);
    if (!isOtpValid) {
      return;
    }

    setState(() {
      _isEmailLoading = true;
    });

    try {
      final success = await authProvider.signUpWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      if (success) {
        _emailController.clear();
        _verificationCodeController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _resetOtpVerificationState();
        validation.resetValidationState();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      _showDialog(
        authProvider.errorMessage ?? 'Sign-up failed. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEmailLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (_isAnyLoading) {
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
        _navigateAfterGoogleAuth(isNewUser: result.isNewUser);
        return;
      }

      if (!result.wasCancelled) {
        _showErrorSnackBar(
          result.errorMessage ??
              authProvider.errorMessage ??
              'Google sign-up failed. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  void _navigateAfterGoogleAuth({required bool isNewUser}) {
    final destination = isNewUser
        ? const OnboardingScreen()
        : const HomeScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => destination),
      (route) => false,
    );
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  void _resetOtpVerificationState() {
    _isOtpVerified = false;
    _verifiedOtpEmail = null;
    _verifiedOtpCode = null;
    _lastAutoVerifiedCode = null;
  }

  void _invalidateOtpVerificationIfNeeded() {
    if (!_isOtpVerified) {
      return;
    }

    final currentEmail = _emailController.text.trim().toLowerCase();
    final currentOtpCode = _verificationCodeController.text.trim();
    if (_verifiedOtpEmail != currentEmail ||
        _verifiedOtpCode != currentOtpCode) {
      setState(() {
        _resetOtpVerificationState();
      });
    }
  }

  void _handleOtpAutoVerify() {
    final code = _verificationCodeController.text.trim();
    if (code.length != 6) {
      _lastAutoVerifiedCode = null;
      return;
    }

    if (_isAnyLoading || _isOtpVerified) {
      return;
    }

    if (_lastAutoVerifiedCode == code) {
      return;
    }

    _lastAutoVerifiedCode = code;
    unawaited(verifyOtp(showSuccessMessage: false));
  }

  Future<void> _sendOtp() async {
    if (_isAnyLoading) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email first.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorSnackBar('Please enter a valid email address.');
      return;
    }

    setState(() {
      _isOtpSending = true;
      // Preparing for a fresh incoming code.
      _verificationCodeController.clear();
      _resetOtpVerificationState();
    });

    try {
      _otpFailedAttempts = 0;
      _otpLockedUntil = null;

      final response = await http.post(
        Uri.parse(_otpWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showErrorSnackBar('OTP sent to your email.');
      } else {
        _showErrorSnackBar('Failed to send OTP. Please try again.');
      }
    } on Exception catch (_) {
      if (mounted) {
        _showErrorSnackBar('Failed to send OTP. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOtpSending = false;
        });
      }
    }
  }

  void _postOtpFailureUi(String message) {
    // Ensure the loader stops first; then show feedback and clear the field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar(message);
      _verificationCodeController.clear();
    });
  }

  Future<bool> verifyOtp({bool showSuccessMessage = true}) async {
    final email = _emailController.text.trim();
    final normalizedEmail = email.toLowerCase();
    final enteredOtp = _verificationCodeController.text.trim();

    final lockedUntil = _otpLockedUntil;
    if (lockedUntil != null) {
      final remaining = lockedUntil.difference(DateTime.now());
      if (!remaining.isNegative) {
        setState(_resetOtpVerificationState);
        _showErrorSnackBar(
          'Too many incorrect attempts. Try again in ${remaining.inMinutes + 1} minute(s) or request a new code.',
        );
        _verificationCodeController.clear();
        return false;
      }

      _otpLockedUntil = null;
      _otpFailedAttempts = 0;
    }

    if (email.isEmpty) {
      _showErrorSnackBar('Please enter your email first.');
      return false;
    }

    if (enteredOtp.isEmpty) {
      _showErrorSnackBar('Please enter the verification code.');
      return false;
    }

    if (enteredOtp.length != 6) {
      _showErrorSnackBar('Please enter the 6-digit verification code.');
      return false;
    }

    String? failureMessage;
    var shouldResetVerification = false;
    var shouldClearVerificationCode = false;
    var shouldCountFailedAttempt = false;
    var isSuccess = false;

    try {
      if (mounted) {
        setState(() {
          _isOtpVerifying = true;
        });
      }

      final response = await http.post(
        Uri.parse(_verifyOtpWebhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'user_code': enteredOtp}),
      );

      Map<String, dynamic>? responseData;
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          responseData = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }

      final status = responseData?['status']?.toString().toLowerCase();
      final rawMessage = responseData?['message']?.toString();
      final message = (rawMessage != null && rawMessage.trim().isNotEmpty)
          ? rawMessage.trim()
          : 'Unable to verify OTP right now. Please try again.';

      if (status == 'success' &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        _otpFailedAttempts = 0;
        _otpLockedUntil = null;
        isSuccess = true;

        if (mounted) {
          setState(() {
            _isOtpVerified = true;
            _verifiedOtpEmail = normalizedEmail;
            _verifiedOtpCode = enteredOtp;
          });
        }
      } else {
        shouldResetVerification = true;
        shouldClearVerificationCode = true;
        shouldCountFailedAttempt = status == 'fail';
        failureMessage = message;
      }
    } on Exception catch (_) {
      failureMessage = 'Unable to verify OTP right now. Please try again.';
      shouldResetVerification = true;
      shouldClearVerificationCode = true;
    } finally {
      if (shouldCountFailedAttempt) {
        _otpFailedAttempts += 1;
        if (_otpFailedAttempts >= _maxOtpAttempts) {
          _otpLockedUntil = DateTime.now().add(const Duration(minutes: 10));
        }
      }

      if (mounted) {
        setState(() {
          _isOtpVerifying = false;
          if (shouldResetVerification) {
            _resetOtpVerificationState();
          }
        });
      }

      if (failureMessage != null) {
        if (shouldClearVerificationCode) {
          _postOtpFailureUi(failureMessage);
        } else {
          _showErrorSnackBar(failureMessage);
        }
      }
    }

    if (isSuccess && showSuccessMessage) {
      _showErrorSnackBar('OTP verified successfully.');
    }

    return isSuccess;
  }

  Future<void> _showDialog(
    String message, {
    required bool isError,
    Duration? autoDismissAfter,
  }) async {
    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: isError,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'OK',
              style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );

    if (autoDismissAfter != null) {
      await Future<void>.delayed(autoDismissAfter);
      if (!mounted) {
        return;
      }
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
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
      appBar: AppBar(title: const Text('Create Account')),
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Consumer<AuthValidationProvider>(
            builder: (context, validation, _) {
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: _isPasswordHidden,
                              style: AppTextStyles.bodyLarge(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Create your password',
                                hintStyle: AppTextStyles.bodyMedium(
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundSecondary,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderDefault,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.accentPrimary,
                                    width: 1.5,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordHidden = !_isPasswordHidden;
                                    });
                                  },
                                ),
                              ),
                              onChanged: validation.updatePassword,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_showPasswordRules) ...[
                          _buildPasswordRulesDisplay(validation),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Password',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _isConfirmPasswordHidden,
                              style: AppTextStyles.bodyLarge(
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Re-enter your password',
                                hintStyle: AppTextStyles.bodyMedium(
                                  color: AppColors.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundSecondary,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.borderDefault,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.accentPrimary,
                                    width: 1.5,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordHidden
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordHidden =
                                          !_isConfirmPasswordHidden;
                                    });
                                  },
                                ),
                              ),
                              onChanged: validation.updateConfirmPassword,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (_passwordController.text.isNotEmpty ||
                            _confirmPasswordController.text.isNotEmpty)
                          _buildPasswordMatchIndicator(validation),
                        const SizedBox(height: AppSpacing.xl),
                        _BrutlGradientButton(
                          label: _isEmailLoading
                              ? 'Creating Account...'
                              : 'Sign Up with Email',
                          isLoading: _isEmailLoading || _isOtpVerifying,
                          onPressed:
                              (!_isAnyLoading &&
                                  validation.isSignUpButtonEnabled &&
                                  _isOtpVerified)
                              ? _handleSignUp
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildOrDivider(),
                        const SizedBox(height: AppSpacing.lg),
                        _BrutlSecondaryButton(
                          label: 'Sign Up with Google',
                          iconAssetPath: 'assets/Images/google_logo.jpg',
                          isLoading: _isGoogleLoading,
                          onPressed: _isAnyLoading ? null : _handleGoogleSignUp,
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
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
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
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isAnyLoading ? null : _sendOtp,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentPrimary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isOtpSending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentPrimary,
                      ),
                    ),
                  )
                : Text(
                    'Send OTP',
                    style: AppTextStyles.headingSmall(
                      color: AppColors.accentPrimary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Verification Code',
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 52,
          child: TextField(
            controller: _verificationCodeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: AppTextStyles.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter verification code',
              suffixIcon: _isOtpVerified
                  ? const Icon(
                      Icons.verified,
                      color: AppColors.statusSuccess,
                      size: 20,
                    )
                  : null,
            ),
            onSubmitted: (_) async {
              await verifyOtp();
              if (mounted) {
                FocusScope.of(context).requestFocus(_passwordFocusNode);
              }
            },
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
              isLoading ? 'Signing Up...' : label,
              style: AppTextStyles.headingSmall(color: const Color(0xFF1A1A1A)),
            ),
          ],
        ),
      ),
    );
  }
}
