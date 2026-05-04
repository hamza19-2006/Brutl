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
  static const int _maxHistoryDays = 28; // 4 weeks

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

  void onStepCount(StepCount event) {
    final currentDate = _dateKeyFor(DateTime.now());
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

    // New day detected — midnight rollover
    if (_lastResetDate != currentDate) {
      // Save yesterday's final step count to history before resetting
      unawaited(_saveToHistory(_lastResetDate, _todaySteps));

      _baselineSteps = incomingSteps;
      _todaySteps = 0;
      _lastResetDate = currentDate;
      _hasStoredBaseline = true;
      unawaited(_saveState());
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

  /// Save a day's step count into the persistent history Map.
  /// Keeps only the last [_maxHistoryDays] entries (oldest deleted first).
  Future<void> _saveToHistory(String dateKey, int steps) async {
    if (dateKey.isEmpty || steps < 0) return;
    final prefs = _preferences ?? await SharedPreferences.getInstance();

    final history = _readHistory(prefs);
    history[dateKey] = steps;

    // Prune to keep only the most recent _maxHistoryDays entries
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

  /// Reads the full history Map from SharedPreferences.
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

  /// Public method — returns the full history map.
  /// History key format: "YYYY-MM-DD", value: step count.
  /// Today's live value is injected automatically.
  Future<Map<String, int>> getStepHistory() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final history = _readHistory(prefs);
    // Inject today's live steps so chart always shows current day
    final today = _dateKeyFor(DateTime.now());
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

  String _dateKeyFor(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
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
