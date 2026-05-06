import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage_service.dart';

class StepSensorService {
  StepSensorService._();
  static final StepSensorService instance = StepSensorService._();

  static const String _keyLastSavedDate = 'last_saved_date';
  static const String _keyInitialHardwareSteps = 'initial_hardware_steps';
  static const String _keyLatestRaw = 'brutl_step_latest_raw';

  SharedPreferences? _prefs;
  StreamSubscription<StepCount>? _sensorSubscription;
  Timer? _midnightTimer;

  int _initialHardwareSteps = 0;
  int _latestRaw = 0;
  String _lastSavedDate = '';
  int _lastEmittedSteps = -1;
  String? _sensorError;
  Future<void> Function()? _onDailyReset;

  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String? get sensorError => _sensorError;

  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();

  Stream<int> get todaysStepsStream => _stepsController.stream;

  Future<void> initialize({Future<void> Function()? onDailyReset}) async {
    if (_isInitialized) return;

    _onDailyReset = onDailyReset;
    _prefs = await SharedPreferences.getInstance();
    await _syncStagedBackgroundStepsToHive();
    _hydrateFromStorage(); // FIX: now emits 0 immediately when new day detected
    _scheduleMidnightRollover();

    try {
      _sensorSubscription = Pedometer.stepCountStream.listen(
        _onSensorEvent,
        onError: _onSensorError,
        cancelOnError: false,
      );
      _isListening = true;
      _sensorError = null;
      debugPrint('BRUTL_STEPS: Pedometer stream started successfully.');
    } on MissingPluginException catch (e) {
      _sensorError = e.message;
      _isListening = false;
      debugPrint('BRUTL_STEPS: MissingPluginException — ${e.message}');
    } on PlatformException catch (e) {
      _sensorError = e.message ?? e.code;
      _isListening = false;
      debugPrint('BRUTL_STEPS: PlatformException — ${e.message}');
    }

    _isInitialized = true;
  }

  Future<int> getCurrentDailySteps() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final today = _todayStamp();
    final storedDate = prefs.getString(_keyLastSavedDate) ?? '';

    if (storedDate != today) {
      return 0;
    }

    final initial = prefs.getInt(_keyInitialHardwareSteps) ?? 0;
    final latest = prefs.getInt(_keyLatestRaw) ?? 0;
    return calculateDailySteps(
      rawSensor: latest,
      initialHardwareSteps: initial,
    );
  }

  /// FIX: Public method for app-resume date check.
  /// Called by the lifecycle observer so opening the app after midnight
  /// instantly shows 0 without waiting for a sensor event.
  Future<void> checkAndResetIfNewDay() async {
    final today = _todayStamp();
    if (_lastSavedDate == today) return; // same day, nothing to do

    debugPrint(
      'BRUTL_STEPS: [StepSensorService.resume] New day detected '
      '(stored=$_lastSavedDate, today=$today) — resetting stream to 0.',
    );

    // Save yesterday's final count to Hive history
    final yesterdaySteps = calculateDailySteps(
      rawSensor: _latestRaw,
      initialHardwareSteps: _initialHardwareSteps,
    );
    if (yesterdaySteps > 0 && _lastSavedDate.isNotEmpty) {
      await _saveToHiveHistory(_lastSavedDate, yesterdaySteps);
    }

    // Reset baseline — real sensor values come on next pedometer event
    _initialHardwareSteps = 0;
    _latestRaw = 0;
    _lastSavedDate = today;
    _persistState(today);

    // FIX 3: Force-emit 0 so every StreamBuilder rebuilds immediately
    _lastEmittedSteps = -1;
    _emitSteps(0);

    unawaited(_onDailyReset?.call());
  }

  Future<void> refreshFromSensor() async {
    try {
      final event = await Pedometer.stepCountStream.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Sensor read timed out'),
      );
      _onSensorEvent(event);
      debugPrint('BRUTL_STEPS: Manual refresh — raw=${event.steps}');
    } catch (e) {
      debugPrint('BRUTL_STEPS: Manual refresh failed — $e');
      final steps = await getCurrentDailySteps();
      _emitSteps(steps);
    }
  }

  static int calculateDailySteps({
    required int rawSensor,
    required int initialHardwareSteps,
  }) {
    if (rawSensor < initialHardwareSteps) {
      return 0;
    }
    return rawSensor - initialHardwareSteps;
  }

  void _onSensorEvent(StepCount event) {
    final today = _todayStamp();
    final rawSteps = event.steps;

    debugPrint(
      'BRUTL_STEPS: Sensor event — raw=$rawSteps, '
      'initial=$_initialHardwareSteps, date=$_lastSavedDate',
    );

    if (_lastSavedDate != today) {
      _performMidnightRollover(rawSteps, today);
      return;
    }

    if (rawSteps < _initialHardwareSteps) {
      _initialHardwareSteps = rawSteps;
      _latestRaw = rawSteps;
      _persistState(today);
      _emitSteps(0);
      return;
    }

    _latestRaw = rawSteps;
    final dailySteps = calculateDailySteps(
      rawSensor: _latestRaw,
      initialHardwareSteps: _initialHardwareSteps,
    );

    _persistState(today);
    _emitSteps(dailySteps);
  }

  void _onSensorError(Object error) {
    _sensorError = error.toString();
    _isListening = false;
    debugPrint('BRUTL_STEPS: Sensor error — $error');
    _stepsController.addError(error);
  }

  void _performMidnightRollover(int currentRaw, String newDate) {
    final yesterdaySteps = calculateDailySteps(
      rawSensor: _latestRaw,
      initialHardwareSteps: _initialHardwareSteps,
    );

    if (yesterdaySteps > 0 && _lastSavedDate.isNotEmpty) {
      debugPrint(
        'BRUTL_STEPS: Midnight rollover — saving $_lastSavedDate = $yesterdaySteps steps',
      );
      _saveToHiveHistory(_lastSavedDate, yesterdaySteps);
    }

    _initialHardwareSteps = currentRaw;
    _latestRaw = currentRaw;
    _lastSavedDate = newDate;

    _persistState(newDate);
    // Force re-emit even if last emitted was also 0
    _lastEmittedSteps = -1;
    _emitSteps(0);
    _scheduleMidnightRollover();
    unawaited(_onDailyReset?.call());

    debugPrint('BRUTL_STEPS: New day baseline set — initial=$currentRaw');
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now) + const Duration(seconds: 2);

    _midnightTimer = Timer(duration, () {
      debugPrint('BRUTL_STEPS: Midnight timer fired.');
      refreshFromSensor();
    });

    debugPrint(
      'BRUTL_STEPS: Midnight timer scheduled — fires in '
      '${duration.inMinutes}m ${duration.inSeconds % 60}s',
    );
  }

  void _hydrateFromStorage() {
    final today = _todayStamp();
    _lastSavedDate = _prefs?.getString(_keyLastSavedDate) ?? '';

    if (_lastSavedDate == today) {
      // Same day — restore persisted counts and emit them
      _initialHardwareSteps = _prefs?.getInt(_keyInitialHardwareSteps) ?? 0;
      _latestRaw = _prefs?.getInt(_keyLatestRaw) ?? 0;

      final restoredSteps = calculateDailySteps(
        rawSensor: _latestRaw,
        initialHardwareSteps: _initialHardwareSteps,
      );
      _emitSteps(restoredSteps);

      debugPrint(
        'BRUTL_STEPS: Hydrated from storage — initial=$_initialHardwareSteps, '
        'latest=$_latestRaw, steps=$restoredSteps',
      );
    } else {
      // FIX 1: New day detected on init. Save yesterday's data to history,
      // reset counters, then IMMEDIATELY emit 0 before any UI paints.
      debugPrint(
        'BRUTL_STEPS: New day on hydration '
        '(stored="$_lastSavedDate", today="$today") — emitting 0 instantly.',
      );

      // Persist yesterday's count if we have meaningful data
      final yesterdaySteps = calculateDailySteps(
        rawSensor: _latestRaw,
        initialHardwareSteps: _initialHardwareSteps,
      );
      if (yesterdaySteps > 0 && _lastSavedDate.isNotEmpty) {
        unawaited(_saveToHiveHistory(_lastSavedDate, yesterdaySteps));
      }

      // Reset everything for today
      _lastSavedDate = today;
      _initialHardwareSteps = 0;
      _latestRaw = 0;
      _persistState(today);

      // FIX 1: Emit 0 immediately so the UI paints the correct value
      _emitSteps(0);
    }
  }

  void _persistState(String date) {
    _prefs?.setString(_keyLastSavedDate, date);
    _prefs?.setInt(_keyInitialHardwareSteps, _initialHardwareSteps);
    _prefs?.setInt(_keyLatestRaw, _latestRaw);
  }

  Future<void> _saveToHiveHistory(String dateKey, int steps) async {
    try {
      final localStorage = LocalStorageService();
      await localStorage.initialize();
      await localStorage.saveDailySteps(dateKey, steps);
    } catch (e) {
      debugPrint('BRUTL_STEPS: Failed to save to Hive history — $e');
    }
  }

  Future<void> _syncStagedBackgroundStepsToHive() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('brutl_pending_hive_steps_'))
        .toList();
    if (keys.isEmpty) return;

    for (final key in keys) {
      final dateString = key.replaceFirst('brutl_pending_hive_steps_', '');
      final steps = prefs.getInt(key);
      if (steps != null && steps > 0) {
        await _saveToHiveHistory(dateString, steps);
        debugPrint(
          'BRUTL_STEPS: Synced background staged steps to Hive — $dateString = $steps',
        );
      }
      await prefs.remove(key);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  void _emitSteps(int steps) {
    if (steps == _lastEmittedSteps) return;
    _lastEmittedSteps = steps;
    if (!_stepsController.isClosed) {
      _stepsController.add(steps);
    }
  }

  static String _todayStamp() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  static String dateStampFor(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  void dispose() {
    _sensorSubscription?.cancel();
    _midnightTimer?.cancel();
    _stepsController.close();
  }
}
