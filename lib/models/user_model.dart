import 'package:flutter/foundation.dart';

@immutable
class BrutlUser {
  const BrutlUser({
    required this.uid,
    this.displayName = '',
    this.username = '',
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
  });

  final String uid;
  final String displayName;
  final String username;
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

  BrutlUser copyWith({
    String? uid,
    String? displayName,
    String? username,
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
  }) {
    return BrutlUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
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
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'username': username,
      'gender': gender,
      'age': age,
      'height': height,
      'heightUnit': heightUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'bodyFatString': bodyFatString,
      'body_fat_string': bodyFatString,
      'bodyFatAverage': bodyFatAverage,
      'body_fat_average': bodyFatAverage,
      'dailySteps': dailySteps,
      'step_goal': dailySteps,
      'bodyGoal': bodyGoal,
      'workoutSplitTemplate': workoutSplitTemplate,
      'customSplitDays': customSplitDays,
      'compoundRepMin': compoundRepMin,
      'compoundRepMax': compoundRepMax,
      'isolationRepMin': isolationRepMin,
      'isolationRepMax': isolationRepMax,
      'compound_rep_min': compoundRepMin,
      'compound_rep_max': compoundRepMax,
      'isolation_rep_min': isolationRepMin,
      'isolation_rep_max': isolationRepMax,
      'targetCalories': targetCalories,
      'maintenance_calories': maintenanceCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFats': targetFats,
      'isProfileComplete': isProfileComplete,
    };
  }

  factory BrutlUser.fromJson(Map<String, dynamic> json) {
    return BrutlUser(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Other',
      age: (json['age'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      heightUnit: json['heightUnit'] as String? ?? 'cm',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weightUnit'] as String? ?? 'kg',
      bodyFatString:
          json['body_fat_string'] as String? ??
          json['bodyFatString'] as String? ??
          '',
      bodyFatAverage:
          (json['body_fat_average'] as num?)?.toDouble() ??
          (json['bodyFatAverage'] as num?)?.toDouble() ??
          0.0,
      dailySteps:
          (json['dailySteps'] as num?)?.toInt() ??
          (json['step_goal'] as num?)?.toInt() ??
          (json['dailyStepGoal'] as num?)?.toInt() ??
          10000,
      bodyGoal: json['bodyGoal'] as String? ?? 'Maintenance',
      workoutSplitTemplate:
          json['workoutSplitTemplate'] as String? ?? 'Push, Pull, Legs, Repeat',
      customSplitDays:
          (json['customSplitDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      compoundRepMin:
          (json['compound_rep_min'] as num?)?.toInt() ??
          (json['compoundRepMin'] as num?)?.toInt() ??
          4,
      compoundRepMax:
          (json['compound_rep_max'] as num?)?.toInt() ??
          (json['compoundRepMax'] as num?)?.toInt() ??
          8,
      isolationRepMin:
          (json['isolation_rep_min'] as num?)?.toInt() ??
          (json['isolationRepMin'] as num?)?.toInt() ??
          8,
      isolationRepMax:
          (json['isolation_rep_max'] as num?)?.toInt() ??
          (json['isolationRepMax'] as num?)?.toInt() ??
          12,
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 2000,
      maintenanceCalories:
          (json['maintenance_calories'] as num?)?.toInt() ??
          (json['maintenanceCalories'] as num?)?.toInt() ??
          (json['targetCalories'] as num?)?.toInt() ??
          2000,
      targetProtein: (json['targetProtein'] as num?)?.toInt() ?? 150,
      targetCarbs: (json['targetCarbs'] as num?)?.toInt() ?? 200,
      targetFats: (json['targetFats'] as num?)?.toInt() ?? 60,
      isProfileComplete: json['isProfileComplete'] as bool? ?? false,
    );
  }
}
