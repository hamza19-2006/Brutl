import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'widgets/edit_screen_scaffold.dart';
import 'widgets/settings_widgets.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const int _minContentLength = 20;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const String _feedbackWebhookUrl = String.fromEnvironment(
    'https://n8n.hamza-systems.tech/webhook/feed/sugg',
    defaultValue: 'https://n8n.hamza-systems.tech/webhook/feed/sugg',
  );

  bool _isFeedback = true;
  int _rating = 5;
  late final TextEditingController _textController;
  late final TextEditingController _nameController;
  bool _isLoading = false;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _textController = TextEditingController()..addListener(_handleTextChanged);
    _nameController = TextEditingController(
      text: currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleTextChanged)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _submitFeedback() async {
    if (_isLoading) {
      return;
    }

    final content = _textController.text.trim();
    if (content.length < _minContentLength) {
      _showSnackBar(
        'Please enter at least 20 characters.',
        AppColors.statusError,
      );
      return;
    }

    if (_feedbackWebhookUrl.isEmpty) {
      _showSnackBar(
        'Feedback service is not configured right now.',
        AppColors.statusError,
      );
      return;
    }

    final payload = <String, dynamic>{
      'type': _isFeedback ? 'Feedback' : 'Suggestion',
      'email': _email,
      'displayName': _nameController.text.trim(),
      'content': content,
      'rating': _isFeedback ? _rating : null,
      'timestamp': DateFormat('yyyy-MM-dd h:mm a').format(DateTime.now()),
    };

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse(_feedbackWebhookUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _textController.clear();
        setState(() => _rating = 5);
        _showSnackBar(
          _isFeedback
              ? 'Thanks for your feedback.'
              : 'Thanks for your suggestion.',
          AppColors.statusSuccess,
        );
        return;
      }

      _showSnackBar(
        _extractResponseMessage(response.body) ??
            'Could not submit right now. Please try again.',
        AppColors.statusError,
      );
    } on TimeoutException {
      if (mounted) {
        _showSnackBar(
          'Request timed out. Please try again.',
          AppColors.statusError,
        );
      }
    } on SocketException {
      if (mounted) {
        _showSnackBar(
          'No internet connection. Please try again.',
          AppColors.statusError,
        );
      }
    } on http.ClientException {
      if (mounted) {
        _showSnackBar(
          'Network error. Please try again.',
          AppColors.statusError,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Something went wrong. Please try again.',
          AppColors.statusError,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _extractResponseMessage(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final responseData = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        for (final key in const ['message', 'error', 'detail']) {
          final value = responseData[key]?.toString().trim();
          if (value != null && value.isNotEmpty) {
            return value;
          }
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: AppTextStyles.bodyMedium(color: Colors.white),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final contentLength = _textController.text.length;
    final isContentValid =
        _textController.text.trim().length >= _minContentLength;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Feedback & Suggestion'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Email'),
                    _ReadOnlyField(value: _email),
                    const SizedBox(height: AppSpacing.xxl),
                    const FieldLabel('Display Name'),
                    TextField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.bodyLarge(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter your name',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const FieldLabel('Type'),
                    Row(
                      children: [
                        Expanded(
                          child: _FeedbackTypeButton(
                            label: 'Feedback',
                            isSelected: _isFeedback,
                            onTap: _isLoading
                                ? null
                                : () => setState(() => _isFeedback = true),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _FeedbackTypeButton(
                            label: 'Suggestion',
                            isSelected: !_isFeedback,
                            onTap: _isLoading
                                ? null
                                : () => setState(() => _isFeedback = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    FieldLabel(
                      _isFeedback ? 'Your Feedback' : 'Your Suggestion',
                    ),
                    TextField(
                      controller: _textController,
                      enabled: !_isLoading,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.bodyLarge(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: _isFeedback
                            ? 'Type your feedback here (minimum 20 characters)...'
                            : 'Type your suggestion here (minimum 20 characters)...',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$contentLength / $_minContentLength min',
                        style: AppTextStyles.labelLarge(
                          color: isContentValid
                              ? AppColors.statusSuccess
                              : AppColors.statusError,
                        ),
                      ),
                    ),
                    if (_isFeedback) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusLarge,
                          ),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rate your experience',
                              style: AppTextStyles.headingSmall(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: List.generate(5, (index) {
                                final isSelected = index < _rating;
                                return IconButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => setState(() {
                                          _rating = index + 1;
                                        }),
                                  icon: Icon(
                                    isSelected ? Icons.star : Icons.star_border,
                                    color: isSelected
                                        ? Colors.amber
                                        : AppColors.textTertiary,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
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
                  onPressed: _isLoading ? null : _submitFeedback,
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
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isFeedback ? 'Submit Feedback' : 'Submit Suggestion',
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
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundQuaternary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Text(
        value,
        style: AppTextStyles.bodyLarge(color: AppColors.textSecondary),
      ),
    );
  }
}

class _FeedbackTypeButton extends StatelessWidget {
  const _FeedbackTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.accentSoft : AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.borderDefault,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.headingSmall(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
