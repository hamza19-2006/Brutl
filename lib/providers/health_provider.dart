// Required sensor permissions for pedometer:
// Android (android/app/src/main/AndroidManifest.xml):
// <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
//
// iOS (ios/Runner/Info.plist):
// <key>NSMotionUsageDescription</key>
// <string>Brutl uses motion data to track your steps and calories.</string>

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_storage_service.dart';

class StepProvider extends ChangeNotifier {
  static const String _baselineDateKey = 'step_baseline_date';
  static const String _baselineRawStepsKey = 'step_baseline_raw';
  static const String _latestRawStepsKey = 'step_latest_raw';

  StreamSubscription<StepCount>? _stepSubscription;
  SharedPreferences? _prefs;
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isInitialized = false;
  bool _isListening = false;
  int _baselineRawSteps = 0;
  int _latestRawSteps = 0;
  int _currentSteps = 0;
  String? _sensorError;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  int get currentSteps => _currentSteps;
  String? get sensorError => _sensorError;
  double get caloriesBurned => _currentSteps * 0.04;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _hydrateStoredStepState();

    // Initialize local steps history (Hive) and seed placeholder data
    await _localStorage.initialize();
    await _localStorage.ensureSeeded();

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCountEvent,
        onError: _onStepCountError,
        cancelOnError: false,
      );
    } on MissingPluginException catch (error) {
      _sensorError = error.message;
      _isListening = false;
      _isInitialized = true;
      notifyListeners();
      return;
    } on PlatformException catch (error) {
      _sensorError = error.message ?? error.code;
      _isListening = false;
      _isInitialized = true;
      notifyListeners();
      return;
    }

    _isInitialized = true;
    _isListening = true;
    notifyListeners();
  }

  void _hydrateStoredStepState() {
    final today = _todayStamp();
    final storedDate = _prefs?.getString(_baselineDateKey);

    if (storedDate == today) {
      _baselineRawSteps = _prefs?.getInt(_baselineRawStepsKey) ?? 0;
      _latestRawSteps = _prefs?.getInt(_latestRawStepsKey) ?? 0;
      _currentSteps = math.max(0, _latestRawSteps - _baselineRawSteps);
      return;
    }

    _persistDailyState(date: today, baselineRawSteps: 0, latestRawSteps: 0);
  }

  void _onStepCountEvent(StepCount event) {
    final today = _todayStamp();
    final storedDate = _prefs?.getString(_baselineDateKey);
    final rawSteps = event.steps;

    if (storedDate != today) {
      _baselineRawSteps = rawSteps;
    } else if (_baselineRawSteps == 0) {
      _baselineRawSteps = _prefs?.getInt(_baselineRawStepsKey) ?? rawSteps;
    }

    _latestRawSteps = rawSteps;
    _currentSteps = math.max(0, _latestRawSteps - _baselineRawSteps);
    _sensorError = null;

    _persistDailyState(
      date: today,
      baselineRawSteps: _baselineRawSteps,
      latestRawSteps: _latestRawSteps,
    );

    // Persist to local history for the steps chart
    unawaited(
      _localStorage.saveDailySteps(today, _currentSteps),
    );

    notifyListeners();
  }

  void _onStepCountError(Object error) {
    _sensorError = error.toString();
    _isListening = false;
    notifyListeners();
  }

  void _persistDailyState({
    required String date,
    required int baselineRawSteps,
    required int latestRawSteps,
  }) {
    _prefs?.setString(_baselineDateKey, date);
    _prefs?.setInt(_baselineRawStepsKey, baselineRawSteps);
    _prefs?.setInt(_latestRawStepsKey, latestRawSteps);
  }

  String _todayStamp() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
  }
}
