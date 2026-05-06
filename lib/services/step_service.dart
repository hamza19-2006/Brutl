import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService extends ChangeNotifier {
  StepService._();

  static final StepService instance = StepService._();

  static const String _baselineStepsKey = 'baseline_steps';
  static const String _todayStepsKey = 'today_steps';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _stepHistoryKey = 'step_history';
  static const int _maxHistoryDays = 28;

  StreamSubscription<StepCount>? _stepSubscription;
  SharedPreferences? _preferences;
  Timer? _hourlyTimer;

  int _baselineSteps = 0;
  int _todaySteps = 0;
  String _lastResetDate = '';
  bool _hasStoredBaseline = false;
  bool _isInitialized = false;
  int _lastEmittedSteps = -1;

  StreamController<int> _stepsController = StreamController<int>.broadcast();

  bool get isInitialized => _isInitialized;
  Stream<int> get todayStepsStream => _stepsController.stream;

  Future<void> initializeStepService() async {
    if (_isInitialized) return;

    _preferences = await SharedPreferences.getInstance();
    final prefs = _preferences!;

    if (_stepsController.isClosed) {
      _stepsController = StreamController<int>.broadcast();
    }

    _baselineSteps = prefs.getInt(_baselineStepsKey) ?? 0;
    _todaySteps = prefs.getInt(_todayStepsKey) ?? 0;
    _lastResetDate = prefs.getString(_lastResetDateKey) ?? '';
    _hasStoredBaseline = prefs.containsKey(_baselineStepsKey);

    // FIX 1: Check date BEFORE emitting steps to the UI.
    // If a new day has started since last launch, reset to 0 immediately
    // so the UI never flashes yesterday's stale count.
    final today = _todayStamp();
    if (_lastResetDate.isNotEmpty && _lastResetDate != today) {
      debugPrint(
        'BRUTL_STEPS: [StepService.init] New day detected '
        '(stored=$_lastResetDate, today=$today) — resetting to 0 before UI paint.',
      );
      // Save yesterday's final count to history before wiping
      if (_todaySteps > 0) {
        await _saveToHistory(_lastResetDate, _todaySteps);
      }
      _todaySteps = 0;
      _lastResetDate = today;
      _hasStoredBaseline = false; // baseline will be set on first sensor event
      await prefs.setInt(_todayStepsKey, 0);
      await prefs.setString(_lastResetDateKey, today);
    }

    // Now emit the correct value (0 if new day, restored count if same day)
    _emitSteps(_todaySteps);

    _stepSubscription ??= Pedometer.stepCountStream.listen(
      onStepCount,
      onError: (Object error) {
        debugPrint('BRUTL_STEPS: Pedometer stream error — $error');
      },
    );

    // Hourly timer — saves today's steps into history so data survives crashes
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_saveToHistory(_lastResetDate, _todaySteps));
    });

    _isInitialized = true;
  }

  /// FIX 2: Public method called on app resume (lifecycle observer).
  /// Re-checks date and resets to 0 if the day rolled over while the
  /// app was backgrounded. Notifies all listeners immediately.
  Future<void> checkAndResetIfNewDay() async {
    final today = _todayStamp();
    if (_lastResetDate == today) return; // nothing to do

    debugPrint(
      'BRUTL_STEPS: [StepService.resume] New day detected '
      '(stored=$_lastResetDate, today=$today) — resetting to 0.',
    );

    final prefs = _preferences ?? await SharedPreferences.getInstance();

    // Persist yesterday's final count before wiping
    if (_todaySteps > 0) {
      await _saveToHistory(_lastResetDate, _todaySteps);
    }

    _todaySteps = 0;
    _lastResetDate = today;
    _hasStoredBaseline = false; // baseline reset on next sensor event
    await prefs.setInt(_todayStepsKey, 0);
    await prefs.setString(_lastResetDateKey, today);

    // FIX 3: Push 0 instantly so every stream listener rebuilds immediately
    _lastEmittedSteps = -1; // force re-emit even if previous was also 0
    _emitSteps(0);
    notifyListeners();
  }

  void onStepCount(StepCount event) {
    final currentDate = _todayStamp();
    final incomingSteps = event.steps < 0 ? 0 : event.steps;

    if (!_hasStoredBaseline || _lastResetDate.isEmpty) {
      _baselineSteps = incomingSteps;
      _todaySteps = 0;
      _lastResetDate = currentDate;
      _hasStoredBaseline = true;
      unawaited(_saveState());
      _emitSteps(_todaySteps);
      notifyListeners();
      return;
    }

    // New day detected via sensor event (belt-and-suspenders alongside init check)
    if (_lastResetDate != currentDate) {
      unawaited(_saveToHistory(_lastResetDate, _todaySteps));

      _baselineSteps = incomingSteps;
      _todaySteps = 0;
      _lastResetDate = currentDate;
      _hasStoredBaseline = true;
      unawaited(_saveState());
      // Force re-emit even if _lastEmittedSteps is already 0
      _lastEmittedSteps = -1;
      _emitSteps(_todaySteps);
      notifyListeners();
      return;
    }

    // Phone rebooted — sensor counter reset below our baseline
    if (incomingSteps < _baselineSteps) {
      _baselineSteps = 0;
      _todaySteps += incomingSteps;
      unawaited(_saveState());
      _emitSteps(_todaySteps);
      notifyListeners();
      return;
    }

    // Normal walking
    int calculated = incomingSteps - _baselineSteps;
    if (calculated < 0) calculated = 0;

    _todaySteps = calculated;
    unawaited(_saveState());
    _emitSteps(_todaySteps);
    notifyListeners();
  }

  // ─── History ─────────────────────────────────────────────────────────────

  Future<void> _saveToHistory(String dateKey, int steps) async {
    if (dateKey.isEmpty || steps < 0) return;
    final prefs = _preferences ?? await SharedPreferences.getInstance();

    final history = _readHistory(prefs);
    history[dateKey] = steps;

    if (history.length > _maxHistoryDays) {
      final sortedKeys = history.keys.toList()..sort();
      final keysToRemove = sortedKeys
          .take(history.length - _maxHistoryDays)
          .toList();
      for (final k in keysToRemove) {
        history.remove(k);
      }
    }

    await prefs.setString(_stepHistoryKey, jsonEncode(history));
    debugPrint('BRUTL_STEPS: Saved history $dateKey = $steps');
  }

  Map<String, int> _readHistory(SharedPreferences prefs) {
    final raw = prefs.getString(_stepHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, int>> getStepHistory() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final history = _readHistory(prefs);
    final today = _todayStamp();
    if (_todaySteps > 0) {
      history[today] = _todaySteps;
    }
    return history;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  double calculateCalories(int steps) {
    final calories = steps * 0.04;
    if (calories > 5000.0) return 5000.0;
    if (calories < 0.0) return 0.0;
    return calories;
  }

  int getTodaySteps() => _todaySteps;

  Future<void> _saveState() async {
    final prefs = _preferences;
    if (prefs == null) return;
    await prefs.setInt(_baselineStepsKey, _baselineSteps);
    await prefs.setInt(_todayStepsKey, _todaySteps);
    await prefs.setString(_lastResetDateKey, _lastResetDate);
  }

  String _todayStamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _emitSteps(int steps) {
    if (steps == _lastEmittedSteps) return;
    _lastEmittedSteps = steps;
    if (!_stepsController.isClosed) {
      _stepsController.add(steps);
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _hourlyTimer?.cancel();
    _stepsController.close();
    super.dispose();
  }
}
