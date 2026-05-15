import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeoService {
  GeoService({FirebaseFirestore? firestore, http.Client? httpClient})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _httpClient = httpClient ?? http.Client();

  static const String _ipInfoToken = String.fromEnvironment(
    'ipinfotoken',
    defaultValue: '',
  );
  static const String _countryCodePrefsPrefix = 'country_code_';

  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  static const Set<String> _tier1Countries = <String>{
    'US',
    'GB',
    'CA',
    'AU',
    'DE',
    'FR',
  };

  static const Map<String, String> _countryNames = <String, String>{
    'PK': 'Pakistan',
    'US': 'United States',
    'GB': 'United Kingdom',
    'CA': 'Canada',
    'AU': 'Australia',
    'DE': 'Germany',
    'FR': 'France',
  };

  static bool isPakistan(String? countryCode) =>
      _normalizeCountryCode(countryCode) == 'PK';

  static bool isTier1(String? countryCode) =>
      _tier1Countries.contains(_normalizeCountryCode(countryCode));

  static String countryName(String? countryCode) {
    final normalized = _normalizeCountryCode(countryCode);
    if (normalized == null || normalized.isEmpty) return '—';
    return _countryNames[normalized] ?? normalized;
  }

  Future<String?> ensureCountryCodeForUser({required String uid}) async {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID cannot be empty');
    }

    final userRef = _firestore.collection('users').doc(uid);

    final snapshot = await userRef.get();
    final firestoreCode = _normalizeCountryCode(
      snapshot.data()?['countryCode']?.toString(),
    );
    if (firestoreCode != null) {
      await _cacheCountryCode(uid: uid, countryCode: firestoreCode);
      return firestoreCode;
    }

    final cachedCode = await _getCachedCountryCode(uid: uid);
    if (cachedCode != null) {
      await _persistCountryCode(userRef: userRef, countryCode: cachedCode);
      return cachedCode;
    }

    if (_ipInfoToken.isEmpty) {
      debugPrint(
        'GEO_SERVICE: IPINFO_TOKEN not configured, country detection disabled',
      );
      return null;
    }

    final detectedCode = await _fetchCountryCodeFromApi();
    if (detectedCode == null) return null;

    await _cacheCountryCode(uid: uid, countryCode: detectedCode);
    await _persistCountryCode(userRef: userRef, countryCode: detectedCode);
    return detectedCode;
  }

  Future<String?> _fetchCountryCodeFromApi() async {
    try {
      final response = await _httpClient
          .get(Uri.parse(_ipInfoUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          'GEO_SERVICE: ipinfo request failed with ${response.statusCode}',
        );
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawCountry = decoded['country'];
      final country = _normalizeCountryCode(
        rawCountry is String ? rawCountry : null,
      );
      return country;
    } on FormatException catch (error) {
      debugPrint('GEO_SERVICE: invalid ipinfo JSON response — $error');
      return null;
    } on TimeoutException {
      debugPrint('GEO_SERVICE: ipinfo request timed out');
      return null;
    } catch (error) {
      debugPrint('GEO_SERVICE: country detection failed — $error');
      return null;
    }
  }

  static String get _ipInfoUrl => 'https://ipinfo.io/json?token=$_ipInfoToken';

  Future<void> _persistCountryCode({
    required DocumentReference<Map<String, dynamic>> userRef,
    required String countryCode,
  }) {
    return userRef.set(<String, dynamic>{
      'countryCode': countryCode,
      'country': countryName(countryCode),
    }, SetOptions(merge: true));
  }

  Future<void> _cacheCountryCode({
    required String uid,
    required String countryCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(uid), countryCode);
  }

  Future<String?> _getCachedCountryCode({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCountryCode(prefs.getString(_prefsKey(uid)));
  }

  static String _prefsKey(String uid) => '$_countryCodePrefsPrefix$uid';

  static String? _normalizeCountryCode(String? rawCode) {
    final normalized = rawCode?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}
