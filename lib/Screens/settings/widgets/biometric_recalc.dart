import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../models/user_model.dart';
import '../../../services/settings_calculator_service.dart';

/// Background recalculation of `maintenance_calories` whenever a biometric
/// (Height/Weight/Age/Body Fat) changes. Failures are swallowed since the
/// underlying primary edit already succeeded — the maintenance value will
/// be recomputed again on the next biometric change.
Future<void> recalcMaintenanceInBackground(BrutlUser user) async {
  if (user.uid.isEmpty) return;
  try {
    final weightKg = user.weightUnit.toLowerCase() == 'lbs'
        ? user.weight * 0.45359237
        : user.weight;
    final heightCm = user.heightUnit.toLowerCase() == 'in'
        ? user.height * 2.54
        : user.height;
    final maintenance = SettingsCalculatorService.maintenanceCalories(
      weightKg: weightKg,
      heightCm: heightCm,
      ageYears: user.age,
      gender: user.gender,
      dailyStepGoal: user.dailySteps,
      bodyFatAverage: user.bodyFatAverage,
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(<String, dynamic>{
          'maintenance_calories': maintenance,
        }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('SETTINGS: maintenance recalc failed — $e');
  }
}
