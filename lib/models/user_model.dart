import 'package:flutter/foundation.dart';

@immutable
class BrutlUser {
  const BrutlUser({
    required this.uid,
    this.displayName = '',
    this.username = '',
    this.country = '',
    this.gender = 'Other',
    this.age = 0,
    this.height = 0.0,
    this.heightUnit = 'cm',
    this.weight = 0.0,
    this.weightUnit = 'kg',
    this.bodyFatString = '',
    this.bodyFatAverage = 0.0,
    this.dailySteps = 10000,
    this.bodyGoal = 'Maintenance',
    this.workoutSplitTemplate = 'Push, Pull, Legs, Repeat',
    this.customSplitDays = const [],
    this.compoundRepMin = 4,
    this.compoundRepMax = 8,
    this.isolationRepMin = 8,
    this.isolationRepMax = 12,
    this.targetCalories = 2000,
    this.maintenanceCalories = 2000,
    this.targetProtein = 150,
    this.targetCarbs = 200,
    this.targetFats = 60,
    this.isProfileComplete = false,
    this.photoUrl = '',
    this.usernameChangedAt,
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String username;
  final String country;
  final String gender;
  final int age;
  final double height;
  final String heightUnit;
  final double weight;
  final String weightUnit;
  final String bodyFatString;
  final double bodyFatAverage;
  final int dailySteps;
  final String bodyGoal;
  final String workoutSplitTemplate;
  final List<String> customSplitDays;
  final int compoundRepMin;
  final int compoundRepMax;
  final int isolationRepMin;
  final int isolationRepMax;
  final int targetCalories;
  final int maintenanceCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFats;
  final bool isProfileComplete;
  final String photoUrl;
  final DateTime? usernameChangedAt;
  final DateTime? createdAt;

  BrutlUser copyWith({
    String? uid,
    String? displayName,
    String? username,
    String? country,
    String? gender,
    int? age,
    double? height,
    String? heightUnit,
    double? weight,
    String? weightUnit,
    String? bodyFatString,
    double? bodyFatAverage,
    int? dailySteps,
    String? bodyGoal,
    String? workoutSplitTemplate,
    List<String>? customSplitDays,
    int? compoundRepMin,
    int? compoundRepMax,
    int? isolationRepMin,
    int? isolationRepMax,
    int? targetCalories,
    int? maintenanceCalories,
    int? targetProtein,
    int? targetCarbs,
    int? targetFats,
    bool? isProfileComplete,
    String? photoUrl,
    DateTime? usernameChangedAt,
    DateTime? createdAt,
  }) {
    return BrutlUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      country: country ?? this.country,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      bodyFatString: bodyFatString ?? this.bodyFatString,
      bodyFatAverage: bodyFatAverage ?? this.bodyFatAverage,
      dailySteps: dailySteps ?? this.dailySteps,
      bodyGoal: bodyGoal ?? this.bodyGoal,
      workoutSplitTemplate: workoutSplitTemplate ?? this.workoutSplitTemplate,
      customSplitDays: customSplitDays ?? this.customSplitDays,
      compoundRepMin: compoundRepMin ?? this.compoundRepMin,
      compoundRepMax: compoundRepMax ?? this.compoundRepMax,
      isolationRepMin: isolationRepMin ?? this.isolationRepMin,
      isolationRepMax: isolationRepMax ?? this.isolationRepMax,
      targetCalories: targetCalories ?? this.targetCalories,
      maintenanceCalories: maintenanceCalories ?? this.maintenanceCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFats: targetFats ?? this.targetFats,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      photoUrl: photoUrl ?? this.photoUrl,
      usernameChangedAt: usernameChangedAt ?? this.usernameChangedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'display_name': displayName,
      'username': username,
      'country': country,
      'gender': gender,
      'age': age,
      'height': height,
      'height_unit': heightUnit,
      'weight': weight,
      'weight_unit': weightUnit,
      'body_fat_string': bodyFatString,
      'body_fat_average': bodyFatAverage,
      'step_goal': dailySteps,
      'body_goal': bodyGoal,
      'workout_split_template': workoutSplitTemplate,
      'custom_split_days': customSplitDays,
      'compound_rep_min': compoundRepMin,
      'compound_rep_max': compoundRepMax,
      'isolation_rep_min': isolationRepMin,
      'isolation_rep_max': isolationRepMax,
      'target_calories': targetCalories,
      'maintenance_calories': maintenanceCalories,
      'target_protein': targetProtein,
      'target_carbs': targetCarbs,
      'target_fats': targetFats,
      'is_profile_complete': isProfileComplete,
      'photo_url': photoUrl,
      if (usernameChangedAt != null)
        'username_changed_at': usernameChangedAt!.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }

  factory BrutlUser.fromJson(Map<String, dynamic> json) {
    return BrutlUser(
      uid: json['uid'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      country:
          (json['country'] as String?) ??
          (json['user_country'] as String?) ??
          (json['userCountry'] as String?) ??
          (json['countryCode'] as String?) ??
          (json['country_code'] as String?) ??
          '',
      gender: json['gender'] as String? ?? 'Other',
      age: (json['age'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      heightUnit: json['height_unit'] as String? ?? 'cm',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weight_unit'] as String? ?? 'kg',
      bodyFatString: json['body_fat_string'] as String? ?? '',
      bodyFatAverage: (json['body_fat_average'] as num?)?.toDouble() ?? 0.0,
      dailySteps:
          (json['step_goal'] as num?)?.toInt() ??
          (json['daily_steps'] as num?)?.toInt() ??
          10000,
      bodyGoal: json['body_goal'] as String? ?? 'Maintenance',
      workoutSplitTemplate:
          json['workout_split_template'] as String? ??
          'Push, Pull, Legs, Repeat',
      customSplitDays:
          (json['custom_split_days'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      compoundRepMin: (json['compound_rep_min'] as num?)?.toInt() ?? 4,
      compoundRepMax: (json['compound_rep_max'] as num?)?.toInt() ?? 8,
      isolationRepMin: (json['isolation_rep_min'] as num?)?.toInt() ?? 8,
      isolationRepMax: (json['isolation_rep_max'] as num?)?.toInt() ?? 12,
      targetCalories: (json['target_calories'] as num?)?.toInt() ?? 2000,
      maintenanceCalories:
          (json['maintenance_calories'] as num?)?.toInt() ?? 2000,
      targetProtein: (json['target_protein'] as num?)?.toInt() ?? 150,
      targetCarbs: (json['target_carbs'] as num?)?.toInt() ?? 200,
      targetFats: (json['target_fats'] as num?)?.toInt() ?? 60,
      isProfileComplete: json['is_profile_complete'] as bool? ?? false,
      photoUrl:
          (json['photo_url'] as String?) ?? (json['photoUrl'] as String?) ?? '',
      usernameChangedAt: _parseTimestamp(
        json['username_changed_at'] ?? json['usernameChangedAt'],
      ),
      createdAt: _parseTimestamp(json['created_at'] ?? json['createdAt']),
    );
  }

  static DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      // Firestore Timestamp: dynamic to avoid hard import.
      final dyn = raw as dynamic;
      final dt = dyn.toDate();
      if (dt is DateTime) return dt;
    } catch (_) {}
    return null;
  }
}
