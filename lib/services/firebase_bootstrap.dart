import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  // Kept here for reference; the token itself is wired via:
  // android\app\src\debug\AndroidManifest.xml
  static const String androidAppCheckDebugToken =
      '42C48404-1445-4A9D-8F62-CAD28CBFEC89';

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    await _activateAppCheck();
  }

  static Future<void> _activateAppCheck() async {
    // This project currently configures App Check for Android debug builds.
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    } catch (e) {
      // Don’t crash app startup if App Check isn’t configured correctly yet.
      debugPrint('APP_CHECK: activation failed — $e');
    }
  }
}
