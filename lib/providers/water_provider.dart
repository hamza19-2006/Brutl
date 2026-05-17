import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaterProvider extends ChangeNotifier {
  static const String _goalKey = 'water_goal_liters';
  static const String _dateKeyPrefix = 'water_intake_ml_';

  double _currentIntakeLiters = 0.0;
  double _goalLiters = 4.0;
  String _todayKey = '';

  double get currentIntakeLiters => _currentIntakeLiters;
  double get goalLiters => _goalLiters;
  double get percentage => _goalLiters > 0
      ? (_currentIntakeLiters / _goalLiters).clamp(0.0, 1.0)
      : 0.0;

  static String _makeDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$_dateKeyPrefix$y-$m-$d';
  }

  /// Public helper so history screen can build the same key format.
  static String dateKeyFor(DateTime date) => _makeDateKey(date);

  /// Load goal + today's intake from SharedPreferences.
  /// Call once at app startup from main.dart warmup.
  Future<void> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _goalLiters = prefs.getDouble(_goalKey) ?? 4.0;

    _todayKey = _makeDateKey(DateTime.now());
    final savedMl = prefs.getInt(_todayKey) ?? 0;
    _currentIntakeLiters = savedMl / 1000.0;

    notifyListeners();
  }

  /// Call on app resume — resets intake to zero if the date has changed.
  Future<void> checkAndResetIfNewDay() async {
    final newKey = _makeDateKey(DateTime.now());
    if (_todayKey == newKey) return;

    _todayKey = newKey;
    final prefs = await SharedPreferences.getInstance();
    final savedMl = prefs.getInt(_todayKey) ?? 0;
    _currentIntakeLiters = savedMl / 1000.0;
    notifyListeners();
  }

  /// Add [liters] to today's intake (clamped 0–20 L).
  /// Persists immediately to SharedPreferences.
  Future<void> addWater(double liters) async {
    final newValue = (_currentIntakeLiters + liters).clamp(0.0, 20.0);
    _currentIntakeLiters = newValue;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_todayKey, (newValue * 1000).round());
  }

  /// Update the daily water goal and persist it.
  Future<void> setGoal(double liters) async {
    _goalLiters = liters.clamp(0.5, 10.0);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_goalKey, _goalLiters);
  }

  /// Read water intake for any past date (used by CaloriesHistoryScreen).
  Future<double> getIntakeForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final ml = prefs.getInt(_makeDateKey(date)) ?? 0;
    return ml / 1000.0;
  }
}
