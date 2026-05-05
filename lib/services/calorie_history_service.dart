// ═══════════════════════════════════════════════════════════════════════════════
// CALORIE HISTORY SERVICE — Local-Only 28-Day Rolling Storage
// ═══════════════════════════════════════════════════════════════════════════════
//
// Stores daily macro snapshots in SharedPreferences as JSON.
// Key format : "brutl_cal_history_YYYY-MM-DD"
// Retention  : 28 days (4 rolling weeks). Oldest entries are pruned on every
//              save so storage never grows unbounded.
//
// NO FIREBASE — all reads/writes are strictly local.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single day's macro snapshot.
class DailyMacroSnapshot {
  const DailyMacroSnapshot({
    required this.date,
    required this.calories,
    required this.calorieGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fats,
    required this.fatsGoal,
  });

  final DateTime date;
  final int calories;
  final int calorieGoal;
  final int carbs;
  final int carbsGoal;
  final int protein;
  final int proteinGoal;
  final int fats;
  final int fatsGoal;

  /// Calorie progress clamped to [0, 1].
  double get calorieProgress =>
      calorieGoal <= 0 ? 0 : (calories / calorieGoal).clamp(0.0, 1.0);

  DailyMacroSnapshot copyWith({
    DateTime? date,
    int? calories,
    int? calorieGoal,
    int? carbs,
    int? carbsGoal,
    int? protein,
    int? proteinGoal,
    int? fats,
    int? fatsGoal,
  }) {
    return DailyMacroSnapshot(
      date: date ?? this.date,
      calories: calories ?? this.calories,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      carbs: carbs ?? this.carbs,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      protein: protein ?? this.protein,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      fats: fats ?? this.fats,
      fatsGoal: fatsGoal ?? this.fatsGoal,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': CalorieHistoryService.dateKeyFor(date),
    'calories': calories,
    'calorieGoal': calorieGoal,
    'carbs': carbs,
    'carbsGoal': carbsGoal,
    'protein': protein,
    'proteinGoal': proteinGoal,
    'fats': fats,
    'fatsGoal': fatsGoal,
  };

  factory DailyMacroSnapshot.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String? ?? '';
    return DailyMacroSnapshot(
      date: DateTime.tryParse(dateStr) ?? DateTime.now(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      calorieGoal: (json['calorieGoal'] as num?)?.toInt() ?? 2000,
      carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      carbsGoal: (json['carbsGoal'] as num?)?.toInt() ?? 200,
      protein: (json['protein'] as num?)?.toInt() ?? 0,
      proteinGoal: (json['proteinGoal'] as num?)?.toInt() ?? 150,
      fats: (json['fats'] as num?)?.toInt() ?? 0,
      fatsGoal: (json['fatsGoal'] as num?)?.toInt() ?? 60,
    );
  }

  /// An empty (zero) snapshot for a given date, using provided goals.
  factory DailyMacroSnapshot.empty({
    required DateTime date,
    int calorieGoal = 2000,
    int carbsGoal = 200,
    int proteinGoal = 150,
    int fatsGoal = 60,
  }) => DailyMacroSnapshot(
    date: date,
    calories: 0,
    calorieGoal: calorieGoal,
    carbs: 0,
    carbsGoal: carbsGoal,
    protein: 0,
    proteinGoal: proteinGoal,
    fats: 0,
    fatsGoal: fatsGoal,
  );
}

class CalorieHistoryService {
  CalorieHistoryService._();
  static final CalorieHistoryService instance = CalorieHistoryService._();

  static const int _retentionDays = 28;
  static const String _keyPrefix = 'brutl_cal_history_';

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Save (or overwrite) a snapshot for today.
  /// Automatically prunes entries older than 28 days.
  Future<void> saveSnapshot(DailyMacroSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _dateKey(snapshot.date);
    await prefs.setString(key, jsonEncode(snapshot.toJson()));
    await _prune(prefs);
  }

  /// Save today's macro totals from [NutritionService] in one call.
  ///
  /// Call this whenever nutrition data is updated (e.g. after a meal log).
  Future<void> saveTodayFromNutrition({
    required int calories,
    required int calorieGoal,
    required int carbs,
    required int carbsGoal,
    required int protein,
    required int proteinGoal,
    required int fats,
    required int fatsGoal,
  }) async {
    await saveSnapshot(
      DailyMacroSnapshot(
        date: DateTime.now(),
        calories: calories,
        calorieGoal: calorieGoal,
        carbs: carbs,
        carbsGoal: carbsGoal,
        protein: protein,
        proteinGoal: proteinGoal,
        fats: fats,
        fatsGoal: fatsGoal,
      ),
    );
  }

  /// Load a single snapshot for [date].
  /// Returns null if nothing has been saved for that date.
  Future<DailyMacroSnapshot?> loadSnapshot(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _dateKey(date);
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return DailyMacroSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Load ALL stored snapshots within the 28-day window, sorted newest→oldest.
  Future<List<DailyMacroSnapshot>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final cutoff = _cutoffDate();

    final snapshots = <DailyMacroSnapshot>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final snap = DailyMacroSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (!snap.date.isBefore(cutoff)) {
          snapshots.add(snap);
        }
      } catch (_) {
        // Skip malformed entries silently.
      }
    }

    snapshots.sort((a, b) => b.date.compareTo(a.date));
    return snapshots;
  }

  /// Load snapshots for a specific [week] (Mon–Sun).
  /// Pass a [DateTime] that falls anywhere within the desired week.
  Future<Map<String, DailyMacroSnapshot?>> loadWeek(
    DateTime anyDayInWeek,
  ) async {
    final monday = _mondayOf(anyDayInWeek);
    final result = <String, DailyMacroSnapshot?>{};
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final key = _dateKey(day);
      result[key] = await loadSnapshot(day);
    }
    return result;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Remove all entries older than [_retentionDays].
  Future<void> _prune(SharedPreferences prefs) async {
    final cutoff = _cutoffDate();
    final keysToRemove = <String>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final datePart = key.replaceFirst(_keyPrefix, '');
      final date = DateTime.tryParse(datePart);
      if (date != null && date.isBefore(cutoff)) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  DateTime _cutoffDate() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: _retentionDays));
  }

  static String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  /// Returns the Monday of the week containing [date].
  static DateTime _mondayOf(DateTime date) {
    final daysFromMon = (date.weekday - 1) % 7;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: daysFromMon));
  }

  /// Public helper used by the screen.
  static DateTime mondayOf(DateTime date) => _mondayOf(date);
  static String dateKeyFor(DateTime date) => _dateKey(date);
}
