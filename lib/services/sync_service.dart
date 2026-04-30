import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/brutl_models.dart';

class SyncService {
  final Box<String> _exercisesBox = Hive.box<String>('exercises');

  Future<void> syncPendingExercises() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pendingKeys = <dynamic>[];
    final pendingExercises = <ExerciseModel>[];

    // 1. Identify unsynced items in local DB
    for (var key in _exercisesBox.keys) {
      final jsonString = _exercisesBox.get(key);
      if (jsonString != null) {
        try {
          final exercise = ExerciseModel.fromJson(jsonDecode(jsonString));
          if (!exercise.isSynced) {
            pendingKeys.add(key);
            pendingExercises.add(exercise);
          }
        } catch (e) {
          debugPrint('Error parsing exercise for sync: $e');
        }
      }
    }

    if (pendingExercises.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final workoutsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workouts');

    // 2. Prepare batch write to Firestore
    for (var exercise in pendingExercises) {
      final docRef = workoutsRef.doc(exercise.id);
      batch.set(docRef, exercise.toJson(), SetOptions(merge: true));
    }

    // 3. Commit to Firestore
    try {
      await batch.commit();
      
      // 4. On success, update local items to isSynced: true
      for (int i = 0; i < pendingExercises.length; i++) {
        final syncedExercise = pendingExercises[i].copyWith(isSynced: true);
        await _exercisesBox.put(pendingKeys[i], jsonEncode(syncedExercise.toJson()));
      }
      debugPrint('Successfully synced ${pendingExercises.length} exercises.');
    } catch (e) {
      debugPrint('Sync failed. Will retry later. Error: $e');
    }
  }
}
