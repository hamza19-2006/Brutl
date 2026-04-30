// ═══════════════════════════════════════════════════════════════════════════════
// STEP SENSOR SERVICE — "Sensor Math" Engine
// ═══════════════════════════════════════════════════════════════════════════════
//
// The hardware step sensor returns TOTAL steps since the last device reboot.
// This service converts that into "today's steps" using a persisted midnight
// baseline, with automatic reboot detection and midnight rollover.
//
// Key formula:  todaySteps = currentRaw - midnightBaseline + carryOver
//
// CarryOver only exists if the device was rebooted mid-day (sensor reset to 0).
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage_service.dart';

class StepSensorService {
  StepSensorService._();
  static final StepSensorService instance = StepSensorService._();

  // ─── SharedPreferences keys ───────────────────────────────────────────────
  static const String _keyBaselineDate = 'brutl_step_baseline_date';
  static const String _keyBaselineRaw = 'brutl_step_baseline_raw';
  static const String _keyLatestRaw = 'brutl_step_latest_raw';
  static const String _keyCarryOver = 'brutl_step_carry_over';

  // ─── Internal state ──────────────────────────────────────────────────────
  SharedPreferences? _prefs;
  StreamSubscription<StepCount>? _sensorSubscription;
  Timer? _midnightTimer;

  int _baselineRaw = 0;
  int _latestRaw = 0;
  int _carryOver = 0;
  String _baselineDate = '';
  int _lastEmittedSteps = -1;
  String? _sensorError;

  bool _isInitialized = false;
  bool _isListening = false;

  // ─── Public getters ──────────────────────────────────────────────────────
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String? get sensorError => _sensorError;

  // ─── Stream controller (broadcast so multiple listeners are allowed) ─────
  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();

  /// Continuously yields the calculated daily step count.
  /// Deduplicated: only emits when the value actually changes.
  Stream<int> get todaysStepsStream => _stepsController.stream;

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  /// Initializes the service: loads persisted baseline, starts the hardware
  /// pedometer listener, and schedules the midnight rollover timer.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _hydrateFromStorage();
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

  /// One-shot read of the current daily steps (for background tasks & resume).
  /// Does NOT start the stream; reads from persisted state only.
  Future<int> getCurrentDailySteps() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final today = _todayStamp();
    final storedDate = prefs.getString(_keyBaselineDate) ?? '';

    if (storedDate != today) {
      // Day rolled over since last read — steps are 0 until next sensor event.
      return 0;
    }

    final baseline = prefs.getInt(_keyBaselineRaw) ?? 0;
    final latest = prefs.getInt(_keyLatestRaw) ?? 0;
    final carry = prefs.getInt(_keyCarryOver) ?? 0;

    return calculateDailySteps(
      rawSensor: latest,
      baseline: baseline,
      carryOver: carry,
    );
  }

  /// Manually triggers a refresh by re-reading the latest sensor value.
  /// Useful when the app resumes from background.
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
      // Fall back to persisted state
      final steps = await getCurrentDailySteps();
      _emitSteps(steps);
    }
  }

  /// Pure function — no side effects. Can be called from a background isolate.
  static int calculateDailySteps({
    required int rawSensor,
    required int baseline,
    required int carryOver,
  }) {
    if (rawSensor < baseline) {
      // Reboot detected in a background context — treat rawSensor as fresh
      return math.max(0, carryOver + rawSensor);
    }
    return math.max(0, (rawSensor - baseline) + carryOver);
  }

  // ─── Sensor event handling ──────────────────────────────────────────────

  void _onSensorEvent(StepCount event) {
    final today = _todayStamp();
    final rawSteps = event.steps;

    debugPrint(
      'BRUTL_STEPS: Sensor event — raw=$rawSteps, '
      'baseline=$_baselineRaw, carry=$_carryOver, date=$_baselineDate',
    );

    // ── Midnight rollover check ──
    if (_baselineDate != today) {
      _performMidnightRollover(rawSteps, today);
      return;
    }

    // ── Reboot detection ──
    if (rawSteps < _baselineRaw) {
      _handleReboot(rawSteps);
      return;
    }

    // ── Normal step accumulation ──
    _latestRaw = rawSteps;
    final dailySteps = calculateDailySteps(
      rawSensor: _latestRaw,
      baseline: _baselineRaw,
      carryOver: _carryOver,
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

  // ─── Reboot detection ────────────────────────────────────────────────────

  void _handleReboot(int newRawAfterReboot) {
    // Steps accumulated before the reboot become carry-over.
    final stepsBeforeReboot = math.max(0, _latestRaw - _baselineRaw);
    _carryOver += stepsBeforeReboot;
    _baselineRaw = newRawAfterReboot;
    _latestRaw = newRawAfterReboot;

    final dailySteps = calculateDailySteps(
      rawSensor: _latestRaw,
      baseline: _baselineRaw,
      carryOver: _carryOver,
    );

    debugPrint(
      'BRUTL_STEPS: REBOOT detected — carryOver=$_carryOver, '
      'newBaseline=$_baselineRaw, dailySteps=$dailySteps',
    );

    _persistState(_baselineDate);
    _emitSteps(dailySteps);
  }

  // ─── Midnight rollover ──────────────────────────────────────────────────

  void _performMidnightRollover(int currentRaw, String newDate) {
    // Persist yesterday's final step count to Hive history.
    final yesterdaySteps = calculateDailySteps(
      rawSensor: _latestRaw,
      baseline: _baselineRaw,
      carryOver: _carryOver,
    );

    if (yesterdaySteps > 0 && _baselineDate.isNotEmpty) {
      debugPrint(
        'BRUTL_STEPS: Midnight rollover — saving $_baselineDate = $yesterdaySteps steps',
      );
      _saveToHiveHistory(_baselineDate, yesterdaySteps);
    }

    // Reset for the new day.
    _baselineRaw = currentRaw;
    _latestRaw = currentRaw;
    _carryOver = 0;
    _baselineDate = newDate;

    _persistState(newDate);
    _emitSteps(0); // Fresh day starts at 0.
    _scheduleMidnightRollover();

    debugPrint('BRUTL_STEPS: New day baseline set — raw=$currentRaw');
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final duration = nextMidnight.difference(now) + const Duration(seconds: 2);

    _midnightTimer = Timer(duration, () {
      debugPrint('BRUTL_STEPS: Midnight timer fired.');
      // Force a sensor re-read to trigger rollover logic.
      refreshFromSensor();
    });

    debugPrint(
      'BRUTL_STEPS: Midnight timer scheduled — fires in '
      '${duration.inMinutes}m ${duration.inSeconds % 60}s',
    );
  }

  // ─── Persistence ────────────────────────────────────────────────────────

  void _hydrateFromStorage() {
    final today = _todayStamp();
    _baselineDate = _prefs?.getString(_keyBaselineDate) ?? '';

    if (_baselineDate == today) {
      _baselineRaw = _prefs?.getInt(_keyBaselineRaw) ?? 0;
      _latestRaw = _prefs?.getInt(_keyLatestRaw) ?? 0;
      _carryOver = _prefs?.getInt(_keyCarryOver) ?? 0;

      final restoredSteps = calculateDailySteps(
        rawSensor: _latestRaw,
        baseline: _baselineRaw,
        carryOver: _carryOver,
      );
      _emitSteps(restoredSteps);

      debugPrint(
        'BRUTL_STEPS: Hydrated from storage — baseline=$_baselineRaw, '
        'latest=$_latestRaw, carry=$_carryOver, steps=$restoredSteps',
      );
    } else {
      // Different day (or first launch) — will be set on first sensor event.
      debugPrint(
        'BRUTL_STEPS: Stored date "$_baselineDate" ≠ today "$today". '
        'Waiting for first sensor event to set baseline.',
      );
      _baselineDate = today;
      _baselineRaw = 0;
      _latestRaw = 0;
      _carryOver = 0;
    }
  }

  void _persistState(String date) {
    _prefs?.setString(_keyBaselineDate, date);
    _prefs?.setInt(_keyBaselineRaw, _baselineRaw);
    _prefs?.setInt(_keyLatestRaw, _latestRaw);
    _prefs?.setInt(_keyCarryOver, _carryOver);
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

  // ─── Helpers ────────────────────────────────────────────────────────────

  void _emitSteps(int steps) {
    if (steps == _lastEmittedSteps) return; // Deduplicate
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

  /// Public accessor so background tasks can build date keys in the same format.
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
