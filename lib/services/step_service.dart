import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StepService {
  StepService._();

  static final StepService instance = StepService._();

  static const String _baselineStepsKey = 'baseline_steps';
  static const String _todayStepsKey = 'today_steps';
  static const String _lastSavedDateKey = 'last_saved_date';

  StreamSubscription<StepCount>? _stepSubscription;
  SharedPreferences? _preferences;
  int _baselineSteps = 0;
  int _todaySteps = 0;
  String _lastSavedDate = '';
  bool _hasStoredBaseline = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initializeStepService() async {
    if (_isInitialized) {
      return;
    }
    _preferences = await SharedPreferences.getInstance();
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    _baselineSteps = preferences.getInt(_baselineStepsKey) ?? 0;
    _todaySteps = preferences.getInt(_todayStepsKey) ?? 0;
    _lastSavedDate = preferences.getString(_lastSavedDateKey) ?? '';
    _hasStoredBaseline = preferences.containsKey(_baselineStepsKey);
    final currentDate = _dateKeyFor(DateTime.now());
    if (_lastSavedDate.isEmpty) {
      _lastSavedDate = currentDate;
      await _saveState();
    }
    _stepSubscription ??= Pedometer.stepCountStream.listen(
      onStepCount,
      onError: (Object error) {
        debugPrint('BRUTL_STEPS: Pedometer stream error — $error');
      },
    );
    _isInitialized = true;
  }

  void onStepCount(StepCount event) {
    final currentDate = _dateKeyFor(DateTime.now());
    final incomingSteps = event.steps < 0 ? 0 : event.steps;
    if (!_hasStoredBaseline) {
      _baselineSteps = incomingSteps;
      _todaySteps = 0;
      _lastSavedDate = currentDate;
      _hasStoredBaseline = true;
      unawaited(_saveState());
      return;
    }
    if (_lastSavedDate != currentDate) {
      _baselineSteps = incomingSteps;
      _todaySteps = 0;
      _lastSavedDate = currentDate;
      _hasStoredBaseline = true;
      unawaited(_saveState());
      return;
    }
    if (incomingSteps < _baselineSteps) {
      _baselineSteps = 0;
      _todaySteps += incomingSteps;
      unawaited(_saveState());
      return;
    }
    _todaySteps = incomingSteps - _baselineSteps;
    unawaited(_saveState());
  }

  double calculateCalories(int todaySteps) {
    final calories = todaySteps * 0.04;
    if (calories > 5000) {
      return 5000;
    }
    if (calories < 0) {
      return 0;
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
    await preferences.setString(_lastSavedDateKey, _lastSavedDate);
    await _syncFirestore();
  }

  Future<void> _syncFirestore() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }
    final calories = calculateCalories(_todaySteps);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .set(<String, dynamic>{
          'baseline_steps': _baselineSteps,
          'dailySteps': _todaySteps,
          'dailyCaloriesBurned': calories,
          'lastStepResetDate': _lastSavedDate,
          'last_saved_date': _lastSavedDate,
        }, SetOptions(merge: true));
  }

  String _dateKeyFor(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
