import 'package:flutter/foundation.dart';

enum WorkoutSplitType { chestTriceps, backBiceps, legsShoulders }

extension WorkoutSplitTypeX on WorkoutSplitType {
  String get id => switch (this) {
    WorkoutSplitType.chestTriceps => 'chest_triceps',
    WorkoutSplitType.backBiceps => 'back_biceps',
    WorkoutSplitType.legsShoulders => 'legs_shoulders',
  };
}

WorkoutSplitType workoutSplitTypeFromId(String id) {
  return WorkoutSplitType.values.firstWhere(
    (type) => type.id == id,
    orElse: () => WorkoutSplitType.chestTriceps,
  );
}

@immutable
class MacroNutrientModel {
  const MacroNutrientModel({required this.consumed, required this.goal});

  final int consumed;
  final int goal;

  double get progress {
    if (goal <= 0) {
      return 0;
    }
    return (consumed / goal).clamp(0.0, 1.0).toDouble();
  }

  MacroNutrientModel copyWith({int? consumed, int? goal}) {
    return MacroNutrientModel(
      consumed: consumed ?? this.consumed,
      goal: goal ?? this.goal,
    );
  }
}

@immutable
class NutritionModel {
  const NutritionModel({
    required this.totalCal,
    required this.goalCal,
    required this.carbs,
    required this.protein,
    required this.fats,
    required this.meals,
  });

  final int totalCal;
  final int goalCal;
  final MacroNutrientModel carbs;
  final MacroNutrientModel protein;
  final MacroNutrientModel fats;
  final Map<String, int> meals;

  NutritionModel copyWith({
    int? totalCal,
    int? goalCal,
    MacroNutrientModel? carbs,
    MacroNutrientModel? protein,
    MacroNutrientModel? fats,
    Map<String, int>? meals,
  }) {
    return NutritionModel(
      totalCal: totalCal ?? this.totalCal,
      goalCal: goalCal ?? this.goalCal,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fats: fats ?? this.fats,
      meals: meals ?? this.meals,
    );
  }
}

@immutable
class ExerciseModel {
  const ExerciseModel({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    this.weightUnit = 'Kg',
    this.isSynced = false,
    this.splitName = '',
  });

  final String id;
  final String name;
  final int sets;
  final String reps;
  final double weight;
  final String weightUnit;
  final bool isSynced;
  final String splitName;
  String get weightDisplay => _formatWeightDisplay(weight, weightUnit);

  double get averageReps {
    final parsedReps = repValues;
    if (parsedReps.isEmpty) {
      return 0;
    }
    final total = parsedReps.fold<int>(0, (sum, value) => sum + value);
    return total / parsedReps.length;
  }

  List<int> get repValues {
    return RegExp(r'\d+')
        .allMatches(reps)
        .map((match) => int.tryParse(match.group(0) ?? '') ?? 0)
        .where((value) => value > 0)
        .toList(growable: false);
  }

  ExerciseModel copyWith({
    String? id,
    String? name,
    int? sets,
    String? reps,
    double? weight,
    String? weightUnit,
    bool? isSynced,
    String? splitName,
  }) {
    return ExerciseModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      isSynced: isSynced ?? this.isSynced,
      splitName: splitName ?? this.splitName,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'weightUnit': weightUnit,
      'weightDisplay': weightDisplay,
      'isSynced': isSynced,
      'splitName': splitName,
    };
  }

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    final setsSource = json['sets'];
    final weightSource = json['weight'];
    final weightUnitSource = json['weightUnit'];
    final weightDisplaySource =
        json['weightDisplay']; // Use display field to recover unit.
    final repsSource = json['reps'];
    final normalizedReps = switch (repsSource) {
      String value => value.trim(),
      List<dynamic> value => value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join(', '),
      num value => value.toInt().toString(),
      _ => '',
    };

    final parsedWeight = _parseWeight(
      weightSource,
      weightUnitSource,
      weightDisplaySource,
    );

    return ExerciseModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sets: setsSource is num
          ? setsSource.toInt()
          : int.tryParse(setsSource?.toString() ?? '') ?? 1,
      reps: normalizedReps.isEmpty ? '10' : normalizedReps,
      weight: parsedWeight.value,
      weightUnit: parsedWeight.unit,
      isSynced: json['isSynced'] as bool? ?? false,
      splitName: json['splitName']?.toString() ?? '',
    );
  }
}

class _ParsedWeight {
  const _ParsedWeight({required this.value, required this.unit});

  final double value;
  final String unit;
}

_ParsedWeight _parseWeight(
  dynamic weightSource,
  dynamic unitSource,
  dynamic displaySource,
) {
  const defaultUnit = 'Kg';
  String unit = unitSource?.toString() ?? defaultUnit;
  double value = 0;

  if (weightSource is num) { // Preferred path: numeric weight value.
    value = weightSource.toDouble(); // Convert numeric weight.
    return _ParsedWeight(value: value, unit: unit); // Return parsed weight.
  }

  final rawValue = weightSource?.toString() ?? ''; // Fallback: string weight value.
  final rawValueParts = rawValue.trim().split(RegExp(r'\s+')); // Split weight/unit.
  if (rawValueParts.isNotEmpty && rawValueParts.first.isNotEmpty) { // Parse numeric portion.
    value = double.tryParse(rawValueParts.first) ?? 0; // Parse weight value.
  }
  if (rawValueParts.length > 1 && unitSource == null) { // Extract unit from weight string.
    unit = rawValueParts.sublist(1).join(' ').trim(); // Use unit from weight string.
  }

  final rawDisplay = displaySource?.toString() ?? ''; // Fallback: display field.
  final displayParts = rawDisplay.trim().split(RegExp(r'\s+')); // Split display value.
  if (displayParts.length > 1 && unitSource == null) { // Extract unit from display.
    unit = displayParts.sublist(1).join(' ').trim(); // Use unit from display.
  }
  if (unit.isEmpty) {
    unit = defaultUnit;
  }

  return _ParsedWeight(value: value, unit: unit);
}

String _formatWeightDisplay(double weight, String unit) {
  final formatted =
      weight % 1 == 0 ? weight.toStringAsFixed(0) : weight.toString();
  return '$formatted $unit';
}

@immutable
class WorkoutSplitModel {
  const WorkoutSplitModel({
    required this.type,
    required this.title,
    required this.exercises,
    required this.updatedAt,
  });

  final WorkoutSplitType type;
  final String title;
  final List<ExerciseModel> exercises;
  final DateTime updatedAt;

  WorkoutSplitModel copyWith({
    WorkoutSplitType? type,
    String? title,
    List<ExerciseModel>? exercises,
    DateTime? updatedAt,
  }) {
    return WorkoutSplitModel(
      type: type ?? this.type,
      title: title ?? this.title,
      exercises: exercises ?? this.exercises,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class WorkoutSessionModel {
  const WorkoutSessionModel({
    required this.id,
    required this.title,
    required this.splits,
  });

  final String id;
  final String title;
  final List<WorkoutSplitModel> splits;

  WorkoutSessionModel copyWith({
    String? id,
    String? title,
    List<WorkoutSplitModel>? splits,
  }) {
    return WorkoutSessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      splits: splits ?? this.splits,
    );
  }
}

@immutable
class ProgramDayModel {
  const ProgramDayModel({
    required this.id,
    required this.weekNumber,
    required this.dayNumber,
    required this.splitName,
    required this.exercises,
  });

  final String id;
  final int weekNumber;
  final int dayNumber;
  final String splitName;
  final List<ExerciseModel> exercises;

  ProgramDayModel copyWith({
    String? id,
    int? weekNumber,
    int? dayNumber,
    String? splitName,
    List<ExerciseModel>? exercises,
  }) {
    return ProgramDayModel(
      id: id ?? this.id,
      weekNumber: weekNumber ?? this.weekNumber,
      dayNumber: dayNumber ?? this.dayNumber,
      splitName: splitName ?? this.splitName,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'weekNumber': weekNumber,
      'dayNumber': dayNumber,
      'splitName': splitName,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  factory ProgramDayModel.fromJson(Map<String, dynamic> json) {
    return ProgramDayModel(
      id: json['id']?.toString() ?? '',
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
      splitName: json['splitName']?.toString() ?? '',
      exercises: (json['exercises'] as List<dynamic>?)
              ?.whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(growable: false) ??
          const <ExerciseModel>[],
    );
  }
}

@immutable
class WorkoutNutritionUiModel {
  const WorkoutNutritionUiModel({
    required this.screenTitle,
    required this.workoutHistoryTitle,
    required this.addNewExerciseLabel,
    required this.logNutritionTitle,
    required this.todaysTotalPrefix,
    required this.caloriesLabel,
    required this.calorieUnit,
    required this.gramsUnit,
    required this.carbsLabel,
    required this.proteinLabel,
    required this.fatsLabel,
    required this.sessionTitles,
    required this.splitTitles,
    required this.mealNames,
    required this.exerciseNameLabel,
    required this.setsLabel,
    required this.repsLabel,
    required this.weightLabel,
    required this.weightUnit,
    required this.saveActionLabel,
    required this.cancelActionLabel,
    required this.addExerciseTitle,
    required this.editExerciseTitle,
    required this.noExercisesMessage,
    required this.invalidInputMessage,
    required this.bottomNavigationLabels,
  });

  final String screenTitle;
  final String workoutHistoryTitle;
  final String addNewExerciseLabel;
  final String logNutritionTitle;
  final String todaysTotalPrefix;
  final String caloriesLabel;
  final String calorieUnit;
  final String gramsUnit;
  final String carbsLabel;
  final String proteinLabel;
  final String fatsLabel;
  final List<String> sessionTitles;
  final Map<WorkoutSplitType, String> splitTitles;
  final List<String> mealNames;
  final String exerciseNameLabel;
  final String setsLabel;
  final String repsLabel;
  final String weightLabel;
  final String weightUnit;
  final String saveActionLabel;
  final String cancelActionLabel;
  final String addExerciseTitle;
  final String editExerciseTitle;
  final String noExercisesMessage;
  final String invalidInputMessage;
  final List<String> bottomNavigationLabels;
}

Map<String, int> orderedMealMap(List<String> mealNames, int value) {
  final map = <String, int>{};
  for (final mealName in mealNames) {
    map[mealName] = value;
  }
  return map;
}
