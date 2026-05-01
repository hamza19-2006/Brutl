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
import 'dart:math' as math;

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
      final storedDate = prefs.getString('brutl_step_baseline_date') ?? '';
      int baselineRaw = prefs.getInt('brutl_step_baseline_raw') ?? 0;
      int latestRaw = prefs.getInt('brutl_step_latest_raw') ?? 0;
      int carryOver = prefs.getInt('brutl_step_carry_over') ?? 0;

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
        final yesterdaySteps = math.max(
          0,
          (latestRaw - baselineRaw) + carryOver,
        );
        if (yesterdaySteps > 0) {
          prefs.setInt('brutl_pending_hive_steps_$storedDate', yesterdaySteps);
          debugPrint(
            'BRUTL_STEPS: [BG] Midnight rollover — staged $storedDate = $yesterdaySteps to SharedPreferences',
          );
        }

        // Reset baseline for new day ONLY AFTER Hive succeeds.
        baselineRaw = currentRaw;
        latestRaw = currentRaw;
        carryOver = 0;

        prefs.setString('brutl_step_baseline_date', today);
        prefs.setInt('brutl_step_baseline_raw', baselineRaw);
        prefs.setInt('brutl_step_latest_raw', latestRaw);
        prefs.setInt('brutl_step_carry_over', carryOver);

        debugPrint('BRUTL_STEPS: [BG] New day baseline set — raw=$currentRaw');
        return Future.value(true);
      }

      // ── 4. First-ever launch (no stored date) ─────────────────────────
      if (storedDate.isEmpty) {
        baselineRaw = currentRaw;
        latestRaw = currentRaw;
        carryOver = 0;

        prefs.setString('brutl_step_baseline_date', today);
        prefs.setInt('brutl_step_baseline_raw', baselineRaw);
        prefs.setInt('brutl_step_latest_raw', latestRaw);
        prefs.setInt('brutl_step_carry_over', carryOver);

        debugPrint('BRUTL_STEPS: [BG] First launch — baseline=$currentRaw');
        return Future.value(true);
      }

      // ── 5. Reboot detection ────────────────────────────────────────────
      if (currentRaw < baselineRaw) {
        final stepsBeforeReboot = math.max(0, latestRaw - baselineRaw);
        carryOver += stepsBeforeReboot;
        baselineRaw = currentRaw;
        debugPrint(
          'BRUTL_STEPS: [BG] Reboot detected — carryOver=$carryOver, '
          'newBaseline=$baselineRaw',
        );
      }

      // ── 6. Calculate ──────────────────────────────────────────
      latestRaw = currentRaw;
      final dailySteps = math.max(0, (latestRaw - baselineRaw) + carryOver);

      // ── 7. Stash today's partial steps in SharedPrefs ───────────────────
      prefs.setInt('brutl_pending_hive_steps_$today', dailySteps);
      
      // ── 8. Persist baselines to SharedPrefs ──────────────────────────────
      prefs.setString('brutl_step_baseline_date', today);
      prefs.setInt('brutl_step_baseline_raw', baselineRaw);
      prefs.setInt('brutl_step_latest_raw', latestRaw);
      prefs.setInt('brutl_step_carry_over', carryOver);

      debugPrint(
        'BRUTL_STEPS: [BG] Task complete — raw=$currentRaw, '
        'baseline=$baselineRaw, carry=$carryOver, daily=$dailySteps',
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
