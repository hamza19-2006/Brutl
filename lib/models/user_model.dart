import 'package:flutter/foundation.dart';

@immutable
class BrutlUser {
  const BrutlUser({
    required this.uid,
    this.displayName = '',
    this.username = '',
    this.height = 0.0,
    this.heightUnit = 'cm',
    this.weight = 0.0,
    this.weightUnit = 'kg',
    this.dailySteps = 10000,
    this.bodyGoal = 'Maintenance',
    this.workoutSplitTemplate = 'Push, Pull, Legs, Repeat',
    this.customSplitDays = const [],
    this.targetCalories = 2000,
    this.targetProtein = 150,
    this.targetCarbs = 200,
    this.targetFats = 60,
    this.isProfileComplete = false,
  });

  final String uid;
  final String displayName;
  final String username;
  final double height;
  final String heightUnit;
  final double weight;
  final String weightUnit;
  final int dailySteps;
  final String bodyGoal;
  final String workoutSplitTemplate;
  final List<String> customSplitDays;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFats;
  final bool isProfileComplete;

  BrutlUser copyWith({
    String? uid,
    String? displayName,
    String? username,
    double? height,
    String? heightUnit,
    double? weight,
    String? weightUnit,
    int? dailySteps,
    String? bodyGoal,
    String? workoutSplitTemplate,
    List<String>? customSplitDays,
    int? targetCalories,
    int? targetProtein,
    int? targetCarbs,
    int? targetFats,
    bool? isProfileComplete,
  }) {
    return BrutlUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      dailySteps: dailySteps ?? this.dailySteps,
      bodyGoal: bodyGoal ?? this.bodyGoal,
      workoutSplitTemplate: workoutSplitTemplate ?? this.workoutSplitTemplate,
      customSplitDays: customSplitDays ?? this.customSplitDays,
      targetCalories: targetCalories ?? this.targetCalories,
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
      'height': height,
      'heightUnit': heightUnit,
      'weight': weight,
      'weightUnit': weightUnit,
      'dailySteps': dailySteps,
      'bodyGoal': bodyGoal,
      'workoutSplitTemplate': workoutSplitTemplate,
      'customSplitDays': customSplitDays,
      'targetCalories': targetCalories,
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
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      heightUnit: json['heightUnit'] as String? ?? 'cm',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weightUnit'] as String? ?? 'kg',
      dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 10000,
      bodyGoal: json['bodyGoal'] as String? ?? 'Maintenance',
      workoutSplitTemplate:
          json['workoutSplitTemplate'] as String? ?? 'Push, Pull, Legs, Repeat',
      customSplitDays:
          (json['customSplitDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 2000,
      targetProtein: (json['targetProtein'] as num?)?.toInt() ?? 150,
      targetCarbs: (json['targetCarbs'] as num?)?.toInt() ?? 200,
      targetFats: (json['targetFats'] as num?)?.toInt() ?? 60,
      isProfileComplete: json['isProfileComplete'] as bool? ?? false,
    );
  }
}
