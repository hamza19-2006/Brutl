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

    unawaited(syncExercise(localExercise));
  }

  Future<void> syncExercise(ExerciseModel exercise) async {
    final user = _auth.currentUser;
    if (user == null) {
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

    final batch = _firestore.batch();
    batch.set(workoutsRef.doc(exercise.id), payload, SetOptions(merge: true));
    batch.set(_firestore.collection('users').doc(user.uid), <String, dynamic>{
      'lastWorkoutUpdatedAt': FieldValue.serverTimestamp(),
      'lastWorkoutSplitName': exercise.splitName,
      'lastWorkoutExerciseId': exercise.id,
    }, SetOptions(merge: true));

    await batch.commit();

    await _exercisesBox.put(
      exercise.id,
      jsonEncode(exercise.copyWith(isSynced: true).toJson()),
    );
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

    await batch.commit();

    for (final exercise in pendingExercises) {
      await _exercisesBox.put(
        exercise.id,
        jsonEncode(exercise.copyWith(isSynced: true).toJson()),
      );
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
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return BrutlUser.fromJson(snapshot.data()!);
  }
}
