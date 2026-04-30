import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isBackgroundReversed = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<BrutlAuthProvider>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<Alignment>(
            tween: AlignmentTween(
              begin: _isBackgroundReversed
                  ? Alignment.bottomRight
                  : Alignment.topLeft,
              end: _isBackgroundReversed
                  ? Alignment.topLeft
                  : Alignment.bottomRight,
            ),
            duration: const Duration(seconds: 8),
            curve: Curves.easeInOutSine,
            onEnd: () {
              if (mounted) {
                setState(() {
                  _isBackgroundReversed = !_isBackgroundReversed;
                });
              }
            },
            builder: (context, alignment, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.breathingAuthGradient,
                ),
              );
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroTitle(context, authProvider),
                          const SizedBox(height: 28),
                          _buildAuthCard(context, authProvider),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTitle(BuildContext context, BrutlAuthProvider authProvider) {
    final title = authProvider.isLoginMode
        ? 'Welcome Back to Brutl'
        : 'Welcome to Brutl';
    return AnimatedSwitcher(
      duration: 280.ms,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Text(
        title,
        key: ValueKey<String>(title),
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.08,
        ),
      ),
    ).animate().fade(duration: 500.ms).slideX(begin: -0.2, duration: 500.ms);
  }

  Widget _buildAuthCard(BuildContext context, BrutlAuthProvider authProvider) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 38),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Centered heading to balance Email + Google options
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Sign in',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFBDBDBD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: 280.ms,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildEmailForm(authProvider),
                ),
                const SizedBox(height: 18),
                _PrimaryActionButton(
                  isLoading: authProvider.isLoading,
                  label: _buttonLabel(authProvider),
                  onTap: () => _handlePrimaryAction(authProvider),
                ),
                const SizedBox(height: 14),
                // Google sign-in — official white branding
                GestureDetector(
                  onTap: () async {
                    final success = await context
                        .read<BrutlAuthProvider>()
                        .signInWithGoogle();
                    if (!context.mounted) return;
                    if (!success) {
                      _showErrorSnackBar(
                        context,
                        context.read<BrutlAuthProvider>().errorMessage ??
                            'Google sign-in failed.',
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Image.asset(
                            'assets/Images/google_logo.png',
                            width: 22,
                            height: 22,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.g_mobiledata,
                                  size: 24,
                                  color: Colors.black54,
                                ),
                          ),
                        ),
                        const Text(
                          'Sign in with Google',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _FooterSwitcher(
                  isLoginMode: authProvider.isLoginMode,
                  onTap: () {
                    context.read<BrutlAuthProvider>().toggleLoginSignup();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm(BrutlAuthProvider authProvider) {
    return Column(
      key: const ValueKey<String>('email-form'),
      children: [
        BrutlTextField(
          controller: _emailController,
          hintText: 'Enter Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        BrutlTextField(
          controller: _passwordController,
          hintText: 'Enter Password',
          obscureText: true,
          textInputAction: authProvider.isLoginMode
              ? TextInputAction.done
              : TextInputAction.next,
        ),
        if (!authProvider.isLoginMode) ...[
          const SizedBox(height: 12),
          BrutlTextField(
            controller: _confirmPasswordController,
            hintText: 'Confirm Password',
            obscureText: true,
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }

  Future<void> _handlePrimaryAction(BrutlAuthProvider authProvider) async {
    final auth = context.read<BrutlAuthProvider>();
    if (authProvider.isLoading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar(context, 'Please enter email and password.');
      return;
    }

    if (!authProvider.isLoginMode) {
      if (_confirmPasswordController.text.trim().isEmpty) {
        _showErrorSnackBar(context, 'Please confirm your password.');
        return;
      }
      if (_confirmPasswordController.text.trim() != password) {
        _showErrorSnackBar(context, 'Passwords do not match.');
        return;
      }
    }

    final success = authProvider.isLoginMode
        ? await auth.signInWithEmail(email: email, password: password)
        : await auth.signUpWithEmail(email: email, password: password);

    if (!mounted || success) {
      return;
    }

    _showErrorSnackBar(context, auth.errorMessage ?? 'Authentication failed.');
    return;
  }

  String _buttonLabel(BrutlAuthProvider provider) {
    return provider.isLoginMode ? 'Sign In' : 'Create Account';
  }
}

class BrutlTextField extends StatefulWidget {
  const BrutlTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.prefixText,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final String? prefixText;

  @override
  State<BrutlTextField> createState() => _BrutlTextFieldState();
}

class _BrutlTextFieldState extends State<BrutlTextField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused ? const Color(0xFFFF3D00) : Colors.transparent,
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Color(0xFF7E7E7E)),
          prefixText: widget.prefixText,
          prefixStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.isLoading,
    required this.label,
    required this.onTap,
  });

  final bool isLoading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: isLoading,
      child: Opacity(
        opacity: isLoading ? 0.75 : 1,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.3,
                          ),
                        )
                      : Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterSwitcher extends StatelessWidget {
  const _FooterSwitcher({required this.isLoginMode, required this.onTap});

  final bool isLoginMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final leading = isLoginMode
        ? "Don't have an account? "
        : 'Already have an account? ';
    final action = isLoginMode ? 'Sign Up' : 'Sign In';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(leading, style: const TextStyle(color: Color(0xFF9A9A9A))),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              color: Color(0xFFFF3D00),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1A1A),
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
}
