import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class BrutlAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool isLoading = false;
  String? errorMessage;
  bool isLoginMode = true;
  bool _isGoogleInitialized = false;

  void toggleLoginSignup() {
    isLoginMode = !isLoginMode;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (error) {
      _setError(_mapAuthException(error));
      return false;
    } catch (_) {
      _setError('Unable to sign in right now. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(<String, dynamic>{
              'email': user.email,
              'uid': user.uid,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
      return true;
    } on FirebaseAuthException catch (error) {
      _setError(_mapAuthException(error));
      return false;
    } on FirebaseException catch (_) {
      _setError('Account created, but profile sync failed.');
      return false;
    } catch (_) {
      _setError('Unable to create account right now. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      if (!_isGoogleInitialized) {
        await _googleSignIn.initialize();
        _isGoogleInitialized = true;
      }

      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        _setError('Unable to authenticate with Google.');
        return false;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(<String, dynamic>{
              'email': user.email,
              'uid': user.uid,
              'displayName': user.displayName,
              'photoUrl': user.photoURL,
              'lastSignInAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
      return true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        _setError('Google sign-in was cancelled.');
        return false;
      }
      _setError('Google sign-in failed. Please try again.');
      return false;
    } on FirebaseAuthException catch (error) {
      _setError(_mapAuthException(error));
      return false;
    } catch (_) {
      _setError('Unable to sign in with Google right now. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);
    try {
      await _auth.signOut();
      if (_isGoogleInitialized) {
        await _googleSignIn.signOut();
      }
    } on FirebaseAuthException catch (error) {
      _setError(_mapAuthException(error));
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> submitOTP({required String otpCode}) async {
    _setLoading(true);
    _setError(null);
    try {
      // TODO: Implement phone auth verification
      await Future<void>.delayed(const Duration(seconds: 1));
      return true;
    } catch (_) {
      _setError('Unable to verify OTP right now. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (isLoading == value) {
      return;
    }
    isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    if (errorMessage == value) {
      return;
    }
    errorMessage = value;
    notifyListeners();
  }

  String _mapAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect credentials. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}
