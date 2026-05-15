// ═══════════════════════════════════════════════════════════════════════════════
// STEP PROVIDER — State Management for Steps & Calories
// ═══════════════════════════════════════════════════════════════════════════════
//
// Listens to StepSensorService.todaysStepsStream (the "Sensor Math" output).
// Manages runtime permission state for Activity Recognition.
// Provides a weight-aware calorie estimation formula.
//
// Required permissions:
//   Android: android.permission.ACTIVITY_RECOGNITION
//   iOS:     NSMotionUsageDescription (Info.plist)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/local_storage_service.dart';
import '../services/step_sensor_service.dart';

class StepProvider extends ChangeNotifier {
  final StepSensorService _sensorService = StepSensorService.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  StreamSubscription<int>? _stepsSubscription;

  // ─── State ───────────────────────────────────────────────────────────────
  bool _isInitialized = false;
  bool _isListening = false;
  int _currentSteps = 0;
  int _previousSteps = -1; // for deduplication
  String? _sensorError;

  // ─── Permission state ────────────────────────────────────────────────────
  bool _hasPermission = false;
  bool _permissionPermanentlyDenied = false;

  // ─── User weight (for calorie formula) ───────────────────────────────────
  double _userWeightKg = 70.0;

  // ─── Public getters ──────────────────────────────────────────────────────
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String? get sensorError => _sensorError;
  bool get hasPermission => _hasPermission;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;

  /// MODULE 1 FIX — Strictly defined, publicly exposed getter for today's
  /// computed steps. Always recomputes from the canonical pair
  /// (raw hardware counter — daily baseline). Defensive against:
  ///   • a stream race where the UI subscribes before baseline emit
  ///   • a corrupted persistence state where baseline was never set
  ///
  /// `int get todaysDisplaySteps => math.max(0, _rawHardwareSteps - _dailyBaseline);`
  int get todaysDisplaySteps {
    if (!_sensorService.isBaselineSetForToday) return 0;
    final raw = _sensorService.rawHardwareSteps;
    final baseline = _sensorService.dailyBaseline;
    return math.max(0, raw - baseline);
  }

  /// Backwards-compatible alias — every caller funnels through the
  /// computed value so the Home Screen can never display the raw
  /// hardware counter (e.g. 20,836).
  int get currentSteps => todaysDisplaySteps;

  /// Calorie estimation using BMR + NEAT model.
  ///
  /// Industry-standard approximation:
  ///   ~0.04 kcal per step per kg of body weight.
  ///
  /// For a 70 kg person: 10,000 steps ≈ 280 kcal (NEAT component).
  /// This aligns with research from the American Council on Exercise.
  ///
  /// MODULE 1 FIX — multiplies the *computed* `todaysDisplaySteps`
  /// by the calorie-per-step multiplier, never the raw hardware counter.
  double get caloriesBurned {
    final weight = _userWeightKg > 0 ? _userWeightKg : 70.0;
    final normalizedWeightFactor = weight / 70.0;
    final estimatedCalories =
        todaysDisplaySteps * 0.04 * normalizedWeightFactor;
    return estimatedCalories.clamp(0, 5000).toDouble();
  }

  // ─── Initialization ─────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize local steps history (Hive) and seed placeholder data.
    await _localStorage.initialize();
    await _localStorage.ensureSeeded();

    // Check permission first (don't start sensor if denied).
    await requestPermissions();

    if (_hasPermission) {
      await _startSensorListening();
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ─── Permission handling ────────────────────────────────────────────────

  /// Checks and requests the Activity Recognition permission.
  /// Sets [hasPermission] and [permissionPermanentlyDenied] accordingly.
  Future<void> requestPermissions() async {
    debugPrint('BRUTL_STEPS: Checking activity recognition permission...');

    final status = await Permission.activityRecognition.status;
    debugPrint('BRUTL_STEPS: Current permission status = $status');

    if (status.isGranted) {
      _hasPermission = true;
      _permissionPermanentlyDenied = false;
      debugPrint('BRUTL_STEPS: Permission already granted.');
      return;
    }

    if (status.isPermanentlyDenied) {
      _hasPermission = false;
      _permissionPermanentlyDenied = true;
      debugPrint('BRUTL_STEPS: Permission permanently denied.');
      notifyListeners();
      return;
    }

    // Request the permission.
    final result = await Permission.activityRecognition.request();
    debugPrint('BRUTL_STEPS: Permission request result = $result');

    if (result.isGranted) {
      _hasPermission = true;
      _permissionPermanentlyDenied = false;
    } else if (result.isPermanentlyDenied) {
      _hasPermission = false;
      _permissionPermanentlyDenied = true;
    } else {
      _hasPermission = false;
      _permissionPermanentlyDenied = false;
    }

    notifyListeners();
  }

  /// Called after user returns from OS Settings. Re-checks permission state
  /// and starts the sensor if now granted.
  Future<void> recheckPermissionAndStart() async {
    await requestPermissions();
    if (_hasPermission && !_isListening) {
      await _startSensorListening();
      notifyListeners();
    }
  }

  // ─── Sensor listening ───────────────────────────────────────────────────

  Future<void> _startSensorListening() async {
    await _sensorService.initialize();

    _sensorError = _sensorService.sensorError;
    _isListening = _sensorService.isListening;

    if (_sensorError != null) {
      debugPrint('BRUTL_STEPS: Sensor service reported error — $_sensorError');
      notifyListeners();
      return;
    }

    // Listen to the deduplicated daily steps stream.
    _stepsSubscription = _sensorService.todaysStepsStream.listen(
      _onStepsUpdated,
      onError: (Object error) {
        _sensorError = error.toString();
        _isListening = false;
        debugPrint(
          'BRUTL_STEPS: Stream error — $error — attempting automatic recovery',
        );
        notifyListeners();

        // Attempt automatic recovery after 5 seconds
        Future<void>.delayed(const Duration(seconds: 5)).then((_) async {
          if (_hasPermission && !_isListening) {
            debugPrint('BRUTL_STEPS: Attempting sensor recovery...');
            await _startSensorListening();
            notifyListeners();
          }
        });
      },
    );
  }

  void _onStepsUpdated(int steps) {
    // Only notify if the value actually changed.
    if (steps == _previousSteps) return;
    _previousSteps = steps;
    _currentSteps = steps;
    _sensorError = null;

    // Persist to local history for the steps chart.
    final today = StepSensorService.dateStampFor(DateTime.now());
    unawaited(_localStorage.saveDailySteps(today, _currentSteps));

    debugPrint('BRUTL_STEPS: UI updated — steps=$_currentSteps');
    notifyListeners();
  }

  // ─── Manual refresh (app resume from background) ────────────────────────

  /// Call this from `didChangeAppLifecycleState(resumed)` to force an
  /// immediate UI update without waiting for the next stream event.
  Future<void> refreshSteps() async {
    if (!_hasPermission) return;

    debugPrint('BRUTL_STEPS: Refreshing steps on app resume...');
    await _sensorService.refreshFromSensor();
  }

  // ─── User weight for calorie formula ────────────────────────────────────

  /// Updates the user weight used in the calorie calculation.
  /// [weight] — the numeric value from the user's profile.
  /// [unit] — 'kg' or 'lbs'. If lbs, it is converted to kg internally.
  void setUserWeight(double weight, String unit) {
    final kg = unit.toLowerCase() == 'lbs' ? weight * 0.453592 : weight;
    if (kg == _userWeightKg) return;
    _userWeightKg = kg > 0 ? kg : 70.0;
    debugPrint(
      'BRUTL_STEPS: User weight set to ${_userWeightKg.toStringAsFixed(1)} kg',
    );

    // Recalculate calories with same step count — only notify if we have steps.
    if (_currentSteps > 0) {
      notifyListeners();
    }
  }

  // ─── Cleanup ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stepsSubscription?.cancel();
    super.dispose();
  }
}
