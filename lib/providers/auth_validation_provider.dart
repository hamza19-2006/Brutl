import 'package:flutter/material.dart';

/// AUTHENTICATION VALIDATION PROVIDER
/// 
/// This provider handles all real-time validation logic for the authentication flow.
/// It manages state for password visibility, validation rules, and form submission.
/// 
/// Key Features:
/// - Real-time password validation (character count, special characters)
/// - Password visibility toggle
/// - Confirm password matching validation
/// - Form submission state management
/// - Error tracking for login attempts

class AuthValidationProvider extends ChangeNotifier {
  // ============ PASSWORD VISIBILITY STATE ============
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool get isPasswordVisible => _isPasswordVisible;
  bool get isConfirmPasswordVisible => _isConfirmPasswordVisible;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    notifyListeners();
  }

  // ============ PASSWORD VALIDATION STATE ============
  // These values track the current password in real-time
  String _currentPassword = '';
  String _confirmPassword = '';

  String get currentPassword => _currentPassword;
  String get confirmPassword => _confirmPassword;

  void updatePassword(String value) {
    _currentPassword = value;
    notifyListeners();
  }

  void updateConfirmPassword(String value) {
    _confirmPassword = value;
    notifyListeners();
  }

  // ============ REAL-TIME VALIDATION LOGIC ============
  // GREEN TEXT VALIDATION: These getters check rules in real-time

  /// Check if password has at least 6 characters
  /// Used to validate Rule 1 and change text color to green
  bool get isSixCharactersValid {
    return _currentPassword.length >= 6;
  }

  /// Check if password contains at least one special character
  /// Special characters: @, #, $, %, &, !, ^, *, etc.
  /// Used to validate Rule 2 and change text color to green
  bool get hasSpecialCharacter {
    final specialCharPattern = RegExp(
      r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]''',
    );
    return specialCharPattern.hasMatch(_currentPassword);
  }

  /// Check if both password fields match
  /// This is crucial for the sign-up confirmation
  bool get doPasswordsMatch {
    return _currentPassword.isNotEmpty &&
        _confirmPassword.isNotEmpty &&
        _currentPassword == _confirmPassword;
  }

  // ============ SIGN-UP BUTTON LOGIC ============
  // DISABLED BUTTON LOGIC: The sign-up button is only enabled when ALL conditions are met

  /// Determines if the Sign-Up button should be enabled
  /// 
  /// Requirements (ALL must be true):
  /// 1. Password is at least 6 characters (Rule 1)
  /// 2. Password contains a special character (Rule 2)
  /// 3. Both password fields match exactly
  /// 
  /// If any condition is false, button remains disabled
  bool get isSignUpButtonEnabled {
    return isSixCharactersValid && hasSpecialCharacter && doPasswordsMatch;
  }

  // ============ LOGIN ERROR STATE ============
  // Track login errors to show "Forgot Password?" link dynamically
  String? _loginError;
  bool _showForgotPasswordLink = false;

  String? get loginError => _loginError;
  bool get showForgotPasswordLink => _showForgotPasswordLink;

  void setLoginError(String? error) {
    _loginError = error;
    // Show "Forgot Password?" link only when there's an error
    _showForgotPasswordLink = error != null && error.isNotEmpty;
    notifyListeners();
  }

  void clearLoginError() {
    _loginError = null;
    _showForgotPasswordLink = false;
    notifyListeners();
  }

  // ============ RESET STATE ============
  /// Call this when user navigates away or completes authentication
  void resetValidationState() {
    _currentPassword = '';
    _confirmPassword = '';
    _isPasswordVisible = false;
    _isConfirmPasswordVisible = false;
    _loginError = null;
    _showForgotPasswordLink = false;
    notifyListeners();
  }
}
