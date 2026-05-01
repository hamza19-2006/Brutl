// ═══════════════════════════════════════════════════════════════════════════════
// BACKGROUND SERVICE — Silent Workmanager Step Sync
// ═══════════════════════════════════════════════════════════════════════════════
//
// This file contains the top-level callback dispatcher for Workmanager.
// It runs in an isolate WITHOUT Flutter UI, so it must:
//   1. NOT reference any Widget, BuildContext, or Provider.
//   2. Initialize its own SharedPreferences and Hive instances.
//   3. Use the pure-function sensor math from StepSensorService.
//
// The periodic task runs approximately every 15 minutes (Android minimum).
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Unique task name used for registration and identification.
const String kBrutlStepSyncTask = 'brutl_step_sync';

/// Must be a top-level function. The `@pragma` annotation ensures the
/// tree-shaker does not remove it in release builds.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('BRUTL_STEPS: [BG] Task "$taskName" started.');

    try {
      // ── 1. Read persisted baseline ─────────────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      final today = _bgTodayStamp();
      final storedDate = prefs.getString('last_saved_date') ?? '';
      int initialHardwareSteps = prefs.getInt('initial_hardware_steps') ?? 0;
      int latestRaw = prefs.getInt('brutl_step_latest_raw') ?? 0;

      // ── 2. Read current hardware step count ────────────────────────────
      int currentRaw;
      try {
        final event = await Pedometer.stepCountStream.first.timeout(
          const Duration(seconds: 5),
        );
        currentRaw = event.steps;
        debugPrint('BRUTL_STEPS: [BG] Sensor read — raw=$currentRaw');
      } catch (e) {
        debugPrint('BRUTL_STEPS: [BG] Sensor read timeout/failed — $e. Falling back to latestRaw.');
        currentRaw = latestRaw;
      }

      // ── 3. Handle midnight rollover ────────────────────────────────────
      if (storedDate != today && storedDate.isNotEmpty) {
        // Save yesterday's final count to Hive.
        final yesterdaySteps = (latestRaw - initialHardwareSteps).clamp(0, 1000000);
        if (yesterdaySteps > 0) {
          prefs.setInt('brutl_pending_hive_steps_$storedDate', yesterdaySteps);
          debugPrint(
            'BRUTL_STEPS: [BG] Midnight rollover — staged $storedDate = $yesterdaySteps to SharedPreferences',
          );
        }

        // Reset baseline for new day ONLY AFTER Hive succeeds.
        initialHardwareSteps = currentRaw;
        latestRaw = currentRaw;

        prefs.setString('last_saved_date', today);
        prefs.setInt('initial_hardware_steps', initialHardwareSteps);
        prefs.setInt('brutl_step_latest_raw', latestRaw);

        debugPrint('BRUTL_STEPS: [BG] New day baseline set — raw=$currentRaw');
        return Future.value(true);
      }

      // ── 4. First-ever launch (no stored date) ─────────────────────────
      if (storedDate.isEmpty) {
        initialHardwareSteps = currentRaw;
        latestRaw = currentRaw;

        prefs.setString('last_saved_date', today);
        prefs.setInt('initial_hardware_steps', initialHardwareSteps);
        prefs.setInt('brutl_step_latest_raw', latestRaw);

        debugPrint('BRUTL_STEPS: [BG] First launch — baseline=$currentRaw');
        return Future.value(true);
      }

      // ── 5. Reboot detection ────────────────────────────────────────────
      if (currentRaw < initialHardwareSteps) {
        initialHardwareSteps = currentRaw;
        debugPrint(
          'BRUTL_STEPS: [BG] Reboot detected — '
          'newInitial=$initialHardwareSteps',
        );
      }

      // ── 6. Calculate ──────────────────────────────────────────
      latestRaw = currentRaw;
      final dailySteps = (latestRaw - initialHardwareSteps).clamp(0, 1000000);

      // ── 7. Stash today's partial steps in SharedPrefs ───────────────────
      prefs.setInt('brutl_pending_hive_steps_$today', dailySteps);
      
      // ── 8. Persist baselines to SharedPrefs ──────────────────────────────
      prefs.setString('last_saved_date', today);
      prefs.setInt('initial_hardware_steps', initialHardwareSteps);
      prefs.setInt('brutl_step_latest_raw', latestRaw);

      debugPrint(
        'BRUTL_STEPS: [BG] Task complete — raw=$currentRaw, '
        'initial=$initialHardwareSteps, daily=$dailySteps',
      );
      return Future.value(true);
    } catch (e, stack) {
      debugPrint('BRUTL_STEPS: [BG] Unhandled error — $e\n$stack');
      // Return true to prevent the OS from marking the task as failed,
      // which would delay future scheduling.
      return Future.value(true);
    }
  });
}

/// Same date stamp format used by StepSensorService.
String _bgTodayStamp() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '${now.year}-$m-$d';
}
