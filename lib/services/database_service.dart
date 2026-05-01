// ═══════════════════════════════════════════════════════════════════════════════
// DATABASE SERVICE — Local-First + Firestore Sync
// ═══════════════════════════════════════════════════════════════════════════════
//
// DATA PERSISTENCE MANDATE:
//   • WORKOUTS, PROFILE, SPLIT NAMES → saved to Hive FIRST (0 ms loading),
//     then synced to Firestore in the background via unawaited batch writes.
//   • STEP DATA → strictly LOCAL ONLY (Hive + SharedPreferences).
//     Step data must NEVER be written to Firestore (cost savings).
//
// This service handles workout/profile persistence only.
// Step persistence lives in LocalStorageService & StepSensorService.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/brutl_models.dart';
import '../models/user_model.dart';

class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _exercisesBox = Hive.box<String>('exercises');
  }

  late final Box<String> _exercisesBox;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> saveExercise(ExerciseModel exercise) async {
    final localExercise = exercise.copyWith(isSynced: false);
    await _exercisesBox.put(
      localExercise.id,
      jsonEncode(localExercise.toJson()),
    );

    // Fire-and-forget sync, but with error tracking
    unawaited(syncExercise(localExercise));
  }

  Future<void> syncExercise(ExerciseModel exercise) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'BRUTL_DB: No user authenticated — cannot sync exercise ${exercise.id}',
      );
      return;
    }

    final workoutsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts');

    final payload = <String, dynamic>{
      ...exercise.toJson(),
      'isSynced': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final batch = _firestore.batch();
      batch.set(workoutsRef.doc(exercise.id), payload, SetOptions(merge: true));
      batch.set(_firestore.collection('users').doc(user.uid), <String, dynamic>{
        'lastWorkoutUpdatedAt': FieldValue.serverTimestamp(),
        'lastWorkoutSplitName': exercise.splitName,
        'lastWorkoutExerciseId': exercise.id,
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('BRUTL_DB: Exercise ${exercise.id} synced successfully');

      // Only mark as synced AFTER Firestore confirms
      await _exercisesBox.put(
        exercise.id,
        jsonEncode(exercise.copyWith(isSynced: true).toJson()),
      );
    } catch (e) {
      debugPrint(
        'BRUTL_DB: Sync failed for exercise ${exercise.id} — $e — keeping local unsync flag',
      );
      // Do NOT update isSynced flag; will retry on next sync attempt
    }
  }

  Future<void> syncPendingExercises() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final pendingExercises = <ExerciseModel>[];
    for (final key in _exercisesBox.keys) {
      final jsonString = _exercisesBox.get(key);
      if (jsonString == null) {
        continue;
      }

      try {
        final exercise = ExerciseModel.fromJson(jsonDecode(jsonString));
        if (!exercise.isSynced) {
          pendingExercises.add(exercise);
        }
      } catch (_) {}
    }

    if (pendingExercises.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    final workoutsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('workouts');

    for (final exercise in pendingExercises) {
      batch.set(workoutsRef.doc(exercise.id), <String, dynamic>{
        ...exercise.toJson(),
        'isSynced': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    batch.set(_firestore.collection('users').doc(user.uid), <String, dynamic>{
      'lastWorkoutUpdatedAt': FieldValue.serverTimestamp(),
      'lastWorkoutSplitName': pendingExercises.last.splitName,
      'lastWorkoutExerciseId': pendingExercises.last.id,
    }, SetOptions(merge: true));

    // CRITICAL: Only mark as synced AFTER batch.commit() succeeds
    try {
      await batch.commit();
      debugPrint('BRUTL_DB: Batch synced ${pendingExercises.length} exercises');

      // Now update local Hive only after Firestore confirms
      for (final exercise in pendingExercises) {
        await _exercisesBox.put(
          exercise.id,
          jsonEncode(exercise.copyWith(isSynced: true).toJson()),
        );
      }
    } catch (e) {
      debugPrint(
        'BRUTL_DB: Batch commit failed — $e — exercises remain unsync for retry',
      );
      // Do NOT update Hive; next call to syncPendingExercises will retry
    }
  }

  List<ExerciseModel> getExercisesForSplit(String splitName) {
    final exercises = <ExerciseModel>[];

    for (final key in _exercisesBox.keys) {
      final jsonString = _exercisesBox.get(key);
      if (jsonString == null) {
        continue;
      }

      try {
        final exercise = ExerciseModel.fromJson(jsonDecode(jsonString));
        if (exercise.splitName == splitName) {
          exercises.add(exercise);
        }
      } catch (_) {}
    }

    return exercises;
  }

  Future<DateTime?> getLatestUpdatedAtForSplit(String splitName) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .where('splitName', isEqualTo: splitName)
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final updatedAt = snapshot.docs.first.data()['updatedAt'];
      if (updatedAt is Timestamp) {
        return updatedAt.toDate();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<BrutlUser?> fetchUserProfile(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return BrutlUser.fromJson(snapshot.data()!);
    } catch (e) {
      debugPrint('BRUTL_DB: fetchUserProfile failed — $e');
      return null;
    }
  }

  Future<void> syncExercisesFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .get();

      for (final doc in snapshot.docs) {
        final exercise = ExerciseModel.fromJson(doc.data());
        // Save to local Hive so it's instantly available offline
        await _exercisesBox.put(
          exercise.id,
          jsonEncode(exercise.copyWith(isSynced: true).toJson()),
        );
      }
      debugPrint(
        'BRUTL_DB: Downloaded ${snapshot.docs.length} exercises from Firestore to local Hive.',
      );
    } catch (e) {
      debugPrint('BRUTL_DB: syncExercisesFromFirestore failed — $e');
    }
  }
}
