import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

/// REUSABLE PASSWORD INPUT FIELD WIDGET
///
/// This widget provides a professional password input field with:
/// - Eye icon toggle to show/hide password
/// - Dynamic icon change (eye vs eye with slash)
/// - Validation feedback with optional hint text
/// - Consistent styling across the app
///
/// Used in both Sign-Up and Login screens

class PasswordInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool isVisible;
  final Function(bool) onVisibilityToggle;
  final String? errorText;
  final Function(String)? onChanged;
  final TextInputAction textInputAction;

  const PasswordInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.isVisible,
    required this.onVisibilityToggle,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),

        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
            border: Border.all(
              color: _isFocused
                  ? AppColors.accentPrimary
                  : widget.errorText != null
                  ? AppColors.statusError
                  : AppColors.borderDefault,
              width: _isFocused ? 1.5 : 1,
            ),
            color: AppColors.backgroundQuaternary,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: !widget.isVisible,
                    textInputAction: widget.textInputAction,
                    onChanged: widget.onChanged,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: AppTextStyles.bodyLarge(
                        color: AppColors.textTertiary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: () => widget.onVisibilityToggle(!widget.isVisible),
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        key: ValueKey<bool>(widget.isVisible),
                        color: _isFocused
                            ? AppColors.accentPrimary
                            : AppColors.textTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Error Text (if any)
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
            child: Text(
              widget.errorText!,
              style: AppTextStyles.labelLarge(color: AppColors.statusError),
            ),
          ),
      ],
    );
  }
}
