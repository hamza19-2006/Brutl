import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService extends ChangeNotifier {
  StepService._();

  static final StepService instance = StepService._();

  static const String _baselineStepsKey = 'baseline_steps';
  static const String _todayStepsKey = 'today_steps';
  static const String _lastResetDateKey = 'last_reset_date'; // Stores last reset date.

  StreamSubscription<StepCount>? _stepSubscription;
  SharedPreferences? _preferences;
  int _baselineSteps = 0;
  int _todaySteps = 0;
  String _lastResetDate = ''; // Tracks last reset date.
  bool _hasStoredBaseline = false;
  bool _isInitialized = false;
  int _lastEmittedSteps = -1; // Keeps last stream emission. 
  StreamController<int> _stepsController =
      StreamController<int>.broadcast(); // Stream for today steps.

  bool get isInitialized => _isInitialized;
  Stream<int> get todayStepsStream => _stepsController.stream; // Expose today steps stream.

  Future<void> initializeStepService() async {
    if (_isInitialized) {
      return;
    }
    _preferences = await SharedPreferences.getInstance();
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    if (_stepsController.isClosed) { // Recreate stream if disposed.
      _stepsController = StreamController<int>.broadcast(); // Rebuild stream.
    }
    _baselineSteps = preferences.getInt(_baselineStepsKey) ?? 0;
    _todaySteps = preferences.getInt(_todayStepsKey) ?? 0;
    _lastResetDate = preferences.getString(_lastResetDateKey) ?? ''; // Load last reset date.
    _hasStoredBaseline = preferences.containsKey(_baselineStepsKey);
    _emitSteps(_todaySteps); // Emit stored steps on init.

    _stepSubscription ??= Pedometer.stepCountStream.listen(
      onStepCount,
      onError: (Object error) {
        debugPrint('BRUTL_STEPS: Pedometer stream error — $error');
      },
    );
    _isInitialized = true;
  }

  void onStepCount(StepCount event) {
    final currentDate = _dateKeyFor(DateTime.now()); // Build date key.
    final incomingSteps = event.steps < 0 ? 0 : event.steps; // Normalize hardware steps.

    // Initialization check: First install/run
    if (!_hasStoredBaseline || _lastResetDate.isEmpty) { // First-run check.
      _baselineSteps = incomingSteps; // Store baseline steps.
      _todaySteps = 0; // Reset today steps.
      _lastResetDate = currentDate; // Set reset date.
      _hasStoredBaseline = true; // Mark baseline stored.
      unawaited(_saveState()); // Persist state.
      _emitSteps(_todaySteps); // Emit today steps.
      notifyListeners(); // Notify listeners.
      return; // Exit early.
    }

    // Check 1 — New Day Detection (Midnight passed)
    if (_lastResetDate != currentDate) { // Detect day change.
      _baselineSteps = incomingSteps; // Reset baseline for new day.
      _todaySteps = 0; // Reset today steps.
      _lastResetDate = currentDate; // Update reset date.
      _hasStoredBaseline = true; // Keep baseline flag.
      unawaited(_saveState()); // Persist state.
      _emitSteps(_todaySteps); // Emit today steps.
      notifyListeners(); // Notify listeners.
      return; // Exit early.
    }

    // Check 2 — Phone Reboot Detection
    if (incomingSteps < _baselineSteps) { // Detect reboot (raw < baseline).
      _baselineSteps = 0; // Reset baseline for reboot.
      _todaySteps += incomingSteps; // Add incoming steps to today total.
      unawaited(_saveState()); // Persist state.
      _emitSteps(_todaySteps); // Emit today steps.
      notifyListeners(); // Notify listeners.
      return; // Exit early.
    }

    // Check 3 — Normal Step Calculation
    int calculatedSteps = incomingSteps - _baselineSteps; // Compute daily steps.
    if (calculatedSteps < 0) { // Guard negative totals.
      calculatedSteps = 0; // Clamp to zero.
    }

    _todaySteps = calculatedSteps; // Store today steps.
    unawaited(_saveState()); // Persist state.
    _emitSteps(_todaySteps); // Emit today steps.
    notifyListeners(); // Notify listeners.
  }

  double calculateCalories(int todaySteps) {
    final calories = todaySteps * 0.04;
    if (calories > 5000.0) {
      return 5000.0;
    }
    if (calories < 0.0) {
      return 0.0;
    }
    return calories;
  }

  int getTodaySteps() {
    return _todaySteps;
  }

  Future<void> _saveState() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    await preferences.setInt(_baselineStepsKey, _baselineSteps);
    await preferences.setInt(_todayStepsKey, _todaySteps);
    await preferences.setString(_lastResetDateKey, _lastResetDate); // Store reset date.
  }

  String _dateKeyFor(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _stepsController.close(); // Close stream controller.
    super.dispose();
  }

  /// Emits today's steps to listeners, skipping duplicate values. // Describe stream emit.
  void _emitSteps(int steps) { // Emit today steps to stream.
    if (steps == _lastEmittedSteps) { // Skip duplicate emissions.
      return; // Exit early.
    }
    _lastEmittedSteps = steps; // Track last emitted steps.
    if (!_stepsController.isClosed) { // Ensure stream is open.
      _stepsController.add(steps); // Publish steps.
    }
  }
}
