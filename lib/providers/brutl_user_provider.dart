import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// Single source-of-truth Provider for the canonical [BrutlUser] document.
///
/// This Provider implements an explicit "Optimistic UI" contract:
/// 1. The caller invokes one of the typed `update*` methods.
/// 2. The local in-memory user is mutated immediately and listeners are
///    notified, so every Settings screen repaints in the same frame.
/// 3. The Firestore write is awaited in the background.
/// 4. If Firestore throws, the previous local user state is restored,
///    listeners are notified again, and the [Exception] is rethrown so
///    the calling screen can show a `SnackBar`.
class BrutlUserProvider extends ChangeNotifier {
  BrutlUserProvider({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BrutlUser _user = const BrutlUser(uid: '');
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  BrutlUser get user => _user;
  bool get isLoading => _isLoading;
  String? get uid =>
      _auth.currentUser?.uid.isNotEmpty == true ? _auth.currentUser!.uid : null;

  /// Subscribe to the live Firestore document for the signed-in user.
  /// Safe to call multiple times — re-subscribes on auth changes.
  Future<void> bindToCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      await _docSub?.cancel();
      _docSub = null;
      _user = const BrutlUser(uid: '');
      notifyListeners();
      return;
    }

    if (_user.uid == firebaseUser.uid && _docSub != null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    await _docSub?.cancel();
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);

    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        _user = BrutlUser.fromJson(snapshot.data()!);
      } else {
        _user = BrutlUser(uid: firebaseUser.uid);
      }
    } catch (e) {
      debugPrint('BRUTL_USER_PROVIDER: initial fetch failed — $e');
      _user = BrutlUser(uid: firebaseUser.uid);
    }

    _docSub = docRef.snapshots().listen(
      (snap) {
        if (snap.exists && snap.data() != null) {
          _user = BrutlUser.fromJson(snap.data()!);
          notifyListeners();
        }
      },
      onError: (Object error) {
        debugPrint('BRUTL_USER_PROVIDER: snapshot error — $error');
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clear() async {
    await _docSub?.cancel();
    _docSub = null;
    _user = const BrutlUser(uid: '');
    notifyListeners();
  }

  /// Optimistic update: mutate locally, then persist patch to Firestore.
  /// On Firestore failure, restores the previous user and rethrows.
  Future<void> applyOptimistic({
    required BrutlUser Function(BrutlUser current) mutate,
    required Map<String, dynamic> firestorePatch,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Not signed in.');
    }

    final previous = _user;
    final next = mutate(previous);
    _user = next;
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(firestorePatch, SetOptions(merge: true));
    } catch (e) {
      debugPrint('BRUTL_USER_PROVIDER: rollback — $e');
      _user = previous;
      notifyListeners();
      rethrow;
    }
  }

  // -------------------- Typed update helpers --------------------

  Future<void> updateDisplayName(String name) {
    final trimmed = name.trim();
    return applyOptimistic(
      mutate: (u) => u.copyWith(displayName: trimmed),
      firestorePatch: <String, dynamic>{
        'display_name': trimmed,
        'displayName': FieldValue.delete(),
      },
    );
  }

  Future<void> updateUsername(String username) {
    final lower = username.trim().toLowerCase();
    return applyOptimistic(
      mutate: (u) =>
          u.copyWith(username: lower, usernameChangedAt: DateTime.now()),
      firestorePatch: <String, dynamic>{
        'username': lower,
        'username_lower': lower,
        'username_changed_at': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> updatePhotoUrl(String url) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(photoUrl: url),
      firestorePatch: <String, dynamic>{
        'photoUrl': url,
        'photo_url': FieldValue.delete(),
      },
    );
  }

  Future<void> updateHeight({required double valueCm}) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(height: valueCm, heightUnit: 'cm'),
      firestorePatch: <String, dynamic>{'height': valueCm, 'height_unit': 'cm'},
    );
  }

  /// Always persists weight in kilograms so existing consumers (e.g.
  /// `WorkoutProvider._toKg`) remain a no-op. [displayUnit] is the unit
  /// the user is currently typing in and is stored separately for UI
  /// rehydration without affecting numeric pipelines.
  Future<void> updateWeight({
    required double valueKg,
    required String displayUnit,
  }) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(weight: valueKg, weightUnit: 'kg'),
      firestorePatch: <String, dynamic>{
        'weight': valueKg,
        'weight_unit': 'kg',
        'weight_display_unit': displayUnit,
      },
    );
  }

  Future<void> updateAge(int years) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(age: years),
      firestorePatch: <String, dynamic>{'age': years},
    );
  }

  Future<void> updateBodyFat({required String label, required double average}) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(bodyFatString: label, bodyFatAverage: average),
      firestorePatch: <String, dynamic>{
        'body_fat_string': label,
        'body_fat_average': average,
      },
    );
  }

  Future<void> updateStepsGoal(int goal) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(dailySteps: goal),
      firestorePatch: <String, dynamic>{'step_goal': goal},
    );
  }

  Future<void> updateMacros({
    required int calories,
    required int carbs,
    required int protein,
    required int fats,
    int? maintenanceCalories,
  }) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(
        targetCalories: calories,
        targetCarbs: carbs,
        targetProtein: protein,
        targetFats: fats,
        maintenanceCalories: maintenanceCalories ?? u.maintenanceCalories,
      ),
      firestorePatch: <String, dynamic>{
        'target_calories': calories,
        'target_carbs': carbs,
        'target_protein': protein,
        'target_fats': fats,
        ...?(maintenanceCalories != null
            ? {'maintenance_calories': maintenanceCalories}
            : null),
      },
    );
  }

  Future<void> updateRepRanges({
    required int compoundMin,
    required int compoundMax,
    required int isolationMin,
    required int isolationMax,
  }) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(
        compoundRepMin: compoundMin,
        compoundRepMax: compoundMax,
        isolationRepMin: isolationMin,
        isolationRepMax: isolationMax,
      ),
      firestorePatch: <String, dynamic>{
        'compound_rep_min': compoundMin,
        'compound_rep_max': compoundMax,
        'isolation_rep_min': isolationMin,
        'isolation_rep_max': isolationMax,
      },
    );
  }

  Future<void> updateMaintenanceCalories(int kcal) {
    return applyOptimistic(
      mutate: (u) => u.copyWith(maintenanceCalories: kcal),
      firestorePatch: <String, dynamic>{'maintenance_calories': kcal},
    );
  }

  /// Case-insensitive uniqueness check using the `username_lower` mirror
  /// field (falls back to `username` when legacy docs don't have it).
  Future<bool> isUsernameAvailable(String candidate) async {
    final lower = candidate.trim().toLowerCase();
    if (lower.isEmpty) return false;
    if (_user.username.toLowerCase() == lower) {
      return true; // unchanged is "available"
    }
    try {
      final byLower = await _firestore
          .collection('users')
          .where('username_lower', isEqualTo: lower)
          .limit(1)
          .get();
      if (byLower.docs.isNotEmpty) {
        return byLower.docs.first.id == _user.uid;
      }
      final byRaw = await _firestore
          .collection('users')
          .where('username', isEqualTo: lower)
          .limit(1)
          .get();
      if (byRaw.docs.isEmpty) return true;
      return byRaw.docs.first.id == _user.uid;
    } catch (e) {
      debugPrint('BRUTL_USER_PROVIDER: username lookup failed — $e');
      rethrow;
    }
  }

  /// Returns null if the user is allowed to change the username now,
  /// otherwise returns the next allowed [DateTime].
  DateTime? usernameNextChangeAllowedAt() {
    final last = _user.usernameChangedAt;
    if (last == null) return null;
    final next = last.add(const Duration(days: 30));
    if (next.isBefore(DateTime.now())) return null;
    return next;
  }

  @override
  void dispose() {
    _docSub?.cancel();
    super.dispose();
  }
}
