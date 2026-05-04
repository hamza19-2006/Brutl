import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.dailyStepGoal = 12000,
    required this.dailyCalorieGoal,
    this.weightKg = 70.0,
  });

  final String id;
  final String name;
  final int dailyStepGoal;
  final int dailyCalorieGoal;
  final double weightKg;

  UserModel copyWith({
    String? id,
    String? name,
    int? dailyStepGoal,
    int? dailyCalorieGoal,
    double? weightKg,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      weightKg: weightKg ?? this.weightKg,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'dailyStepGoal': dailyStepGoal,
      'dailyCalorieGoal': dailyCalorieGoal,
      'weightKg': weightKg,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      dailyStepGoal: (json['dailyStepGoal'] as num?)?.toInt() ?? 12000,
      dailyCalorieGoal: (json['dailyCalorieGoal'] as num).toInt(),
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory UserModel.fromRawJson(String source) =>
      UserModel.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

@immutable
class WorkoutPlanModel {
  const WorkoutPlanModel({required this.weekdayToWorkout});

  final Map<int, String> weekdayToWorkout;

  factory WorkoutPlanModel.defaultPlan() {
    return const WorkoutPlanModel(
      weekdayToWorkout: <int, String>{
        1: 'Chest & Triceps',
        2: 'Back & Biceps',
        3: 'Legs',
        4: 'Shoulders',
        5: 'HIIT & Core',
        6: 'Full Body Strength',
        7: 'Mobility & Recovery',
      },
    );
  }

  String workoutForWeekday(int weekday) {
    return weekdayToWorkout[weekday] ?? 'Recovery';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'weekdayToWorkout': weekdayToWorkout.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json) {
    final rawMap = (json['weekdayToWorkout'] as Map<dynamic, dynamic>? ?? {})
        .map(
          (key, value) =>
              MapEntry(int.tryParse(key.toString()) ?? 0, value.toString()),
        );

    return WorkoutPlanModel(
      weekdayToWorkout: Map<int, String>.from(rawMap)
        ..removeWhere((key, value) => key == 0),
    );
  }
}

@immutable
class ExerciseModel {
  const ExerciseModel({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.imageUrl,
  });

  final String name;
  final int sets;
  final List<int> reps;
  final double weight;
  final String imageUrl;

  double get averageReps =>
      reps.isEmpty ? 0 : reps.reduce((a, b) => a + b) / reps.length;

  double get totalVolume => weight * sets * averageReps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'imageUrl': imageUrl,
    };
  }

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      name: json['name'] as String,
      sets: (json['sets'] as num).toInt(),
      reps: ((json['reps'] as List<dynamic>? ?? const <dynamic>[]))
          .map((rep) => (rep as num).toInt())
          .toList(growable: false),
      weight: (json['weight'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String,
    );
  }
}

@immutable
class HomeUiModel {
  const HomeUiModel({
    required this.brandName,
    required this.daySuffix,
    required this.stepsLabel,
    required this.stepsUnitLabel,
    required this.caloriesLabel,
    required this.caloriesUnitLabel,
    required this.navigationLabels,
    required this.lastWorkoutTitle,
    required this.noWorkoutMessage,
    required this.lastWorkoutSubtitlePrefix,
    required this.lastWorkoutSubtitleSuffix,
    required this.workoutTabTitle,
    required this.workoutFocusPrompt,
    required this.focusedExercisePrefix,
    required this.setsLabel,
    required this.repsLabel,
    required this.weightLabel,
    required this.weightUnit,
  });

  final String brandName;
  final String daySuffix;
  final String stepsLabel;
  final String stepsUnitLabel;
  final String caloriesLabel;
  final String caloriesUnitLabel;
  final List<String> navigationLabels;
  final String lastWorkoutTitle;
  final String noWorkoutMessage;
  final String lastWorkoutSubtitlePrefix;
  final String lastWorkoutSubtitleSuffix;
  final String workoutTabTitle;
  final String workoutFocusPrompt;
  final String focusedExercisePrefix;
  final String setsLabel;
  final String repsLabel;
  final String weightLabel;
  final String weightUnit;
}
