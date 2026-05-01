import 'package:flutter/material.dart';

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
        // Label
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),

        // Password Input Field with Eye Icon
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF6366F1) // Indigo border on focus
                  : widget.errorText != null
                  ? const Color(0xFFF87171) // Red border on error
                  : const Color(0xFFE5E7EB), // Light grey border by default
              width: 2,
            ),
            color: _isFocused
                ? const Color(0xFFF9FAFB)
                : const Color(0xFFFFFFFF),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // Password Input
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
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFD1D5DB),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),

                // Eye Icon Toggle Button
                GestureDetector(
                  onTap: () => widget.onVisibilityToggle(!widget.isVisible),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.isVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        key: ValueKey<bool>(widget.isVisible),
                        color: _isFocused
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF9CA3AF),
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
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFF87171),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
