import 'package:hive/hive.dart';

class LocalStorageService {
  static const String _boxName = 'steps_history';
  static const int _retentionDays = 28;

  Box<int>? _box;

  Future<void> initialize() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<int>(_boxName);
  }

  Future<void> ensureSeeded() async {
    final box = _box;
    if (box == null) return;
    if (box.isNotEmpty) return;

    final now = DateTime.now();
    final placeholders = <String, int>{
      _dateKey(now.subtract(const Duration(days: 3))): 6200,
      _dateKey(now.subtract(const Duration(days: 2))): 11000,
      _dateKey(now.subtract(const Duration(days: 1))): 8500,
    };

    for (final entry in placeholders.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  // Returns the step count for a single date key. Returns 0 if not found.
  int getStepsForKey(String key) {
    return _box?.get(key) ?? 0;
  }

  Map<String, int> getStepsForDateRange(DateTime start, DateTime end) {
    final box = _box;
    if (box == null) return {};

    final result = <String, int>{};
    var cursor = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(endDate)) {
      final key = _dateKey(cursor);
      final value = box.get(key);
      if (value != null) result[key] = value;
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

  /// Returns a 7-element list [Sun, Mon, Tue, Wed, Thu, Fri, Sat]
  /// for the week starting on [weekStart] (Sunday-based, legacy).
  List<int> getWeekData(DateTime weekStart) {
    final box = _box;
    if (box == null) return List.filled(7, 0);

    return List.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      return box.get(_dateKey(date)) ?? 0;
    });
  }

  int get dailyAverage {
    final box = _box;
    if (box == null || box.isEmpty) return 0;
    final values = box.values.toList();
    final total = values.fold<int>(0, (sum, v) => sum + v);
    return (total / values.length).round();
  }

  Future<void> saveDailySteps(String dateKey, int steps) async {
    final box = _box;
    if (box == null) return;
    await box.put(dateKey, steps);
    await _pruneOldEntries();
  }

  Future<void> _pruneOldEntries() async {
    final box = _box;
    if (box == null) return;

    final cutoff = DateTime.now().subtract(
      const Duration(days: _retentionDays),
    );
    final keysToRemove = <String>[];

    for (final key in box.keys.cast<String>()) {
      final date = DateTime.tryParse(key);
      if (date != null && date.isBefore(cutoff)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      await box.delete(key);
    }
  }

  static String _dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  static String dateKeyFor(DateTime date) => _dateKey(date);
}
