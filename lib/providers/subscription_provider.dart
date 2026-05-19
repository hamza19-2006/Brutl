import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SubscriptionPlan { free, pro, proPlus }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen(_handleAuthChange);
    _handleAuthChange(_auth.currentUser);
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  SubscriptionPlan _currentPlan = SubscriptionPlan.free;
  DateTime? _proExpiry;
  DateTime? _proPlusExpiry;
  String _countryCode = 'US';
  String? _boundUid;

  SubscriptionPlan get currentPlan => _currentPlan;
  DateTime? get proExpiry => _proExpiry;
  DateTime? get proPlusExpiry => _proPlusExpiry;
  String get countryCode => _countryCode;
  bool get isPakistan => _countryCode == 'PK';

  SubscriptionPlan getCurrentPlan() => _currentPlan;

  bool get isExpired {
    if (_currentPlan == SubscriptionPlan.pro && _proExpiry != null) {
      return DateTime.now().isAfter(_proExpiry!);
    }
    if (_currentPlan == SubscriptionPlan.proPlus && _proPlusExpiry != null) {
      return DateTime.now().isAfter(_proPlusExpiry!);
    }
    return false;
  }

  bool get isProActive =>
      _currentPlan == SubscriptionPlan.pro &&
      _proExpiry != null &&
      DateTime.now().isBefore(_proExpiry!);

  bool get isProPlusActive =>
      _currentPlan == SubscriptionPlan.proPlus &&
      _proPlusExpiry != null &&
      DateTime.now().isBefore(_proPlusExpiry!);

  Future<void> bindToCurrentUser() async {
    final user = _auth.currentUser;
    await _bindToUser(user);
  }

  void _handleAuthChange(User? user) {
    unawaited(_bindToUser(user));
  }

  Future<void> _bindToUser(User? user) async {
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      await _docSub?.cancel();
      _docSub = null;
      _boundUid = null;
      _applyPlanState(
        planRaw: null,
        proExpiry: null,
        proPlusExpiry: null,
        countryCode: null,
      );
      return;
    }

    if (_boundUid == uid && _docSub != null) {
      return;
    }

    await _docSub?.cancel();
    _boundUid = uid;
    final docRef = _firestore.collection('users').doc(uid);

    try {
      final snapshot = await docRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        _applySnapshot(snapshot.data()!);
      } else {
        _applyPlanState(
          planRaw: null,
          proExpiry: null,
          proPlusExpiry: null,
          countryCode: null,
        );
      }
    } catch (e) {
      debugPrint('SUBSCRIPTION_PROVIDER: initial fetch failed — $e');
      _applyPlanState(
        planRaw: null,
        proExpiry: null,
        proPlusExpiry: null,
        countryCode: null,
      );
    }

    _docSub = docRef.snapshots().listen(
      (snap) {
        if (snap.exists && snap.data() != null) {
          _applySnapshot(snap.data()!);
        }
      },
      onError: (Object error) {
        debugPrint('SUBSCRIPTION_PROVIDER: snapshot error — $error');
      },
    );
  }

  void _applySnapshot(Map<String, dynamic> data) {
    final planRaw =
        (data['subscriptionPlan'] ?? data['subscription_plan']) as String?;
    final proExpiry = _parseTimestamp(data['proExpiry'] ?? data['pro_expiry']);
    final proPlusExpiry = _parseTimestamp(
      data['proPlusExpiry'] ?? data['pro_plus_expiry'],
    );
    final countryCode = data['countryCode']?.toString();
    _applyPlanState(
      planRaw: planRaw,
      proExpiry: proExpiry,
      proPlusExpiry: proPlusExpiry,
      countryCode: countryCode,
    );
  }

  void _applyPlanState({
    required String? planRaw,
    required DateTime? proExpiry,
    required DateTime? proPlusExpiry,
    required String? countryCode,
  }) {
    _proExpiry = proExpiry;
    _proPlusExpiry = proPlusExpiry;
    final normalized = (countryCode ?? 'US').trim().toUpperCase();
    _countryCode = normalized.isEmpty ? 'US' : normalized;
    _currentPlan = _resolvePlan(
      planRaw: planRaw,
      proExpiry: proExpiry,
      proPlusExpiry: proPlusExpiry,
    );
    notifyListeners();
  }

  SubscriptionPlan _resolvePlan({
    required String? planRaw,
    required DateTime? proExpiry,
    required DateTime? proPlusExpiry,
  }) {
    final now = DateTime.now();
    final normalized = (planRaw ?? '').trim().toLowerCase();

    if (normalized == 'proplus') {
      if (proPlusExpiry == null || proPlusExpiry.isAfter(now)) {
        return SubscriptionPlan.proPlus;
      }
    }

    if (normalized == 'pro') {
      if (proExpiry == null || proExpiry.isAfter(now)) {
        return SubscriptionPlan.pro;
      }
    }

    return SubscriptionPlan.free;
  }

  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      final dyn = raw as dynamic;
      final dt = dyn.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _docSub?.cancel();
    super.dispose();
  }
}
