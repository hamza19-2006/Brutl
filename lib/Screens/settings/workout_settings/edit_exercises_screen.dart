import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/brutl_models.dart' as brutl;
import '../../../providers/workout_provider.dart';
import '../widgets/settings_widgets.dart';

class EditExercisesScreen extends StatefulWidget {
  const EditExercisesScreen({super.key, required this.dayName});

  final String dayName;

  @override
  State<EditExercisesScreen> createState() => _EditExercisesScreenState();
}

class _EditExercisesScreenState extends State<EditExercisesScreen> {
  List<brutl.ExerciseModel> _exercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  void _loadExercises() {
    try {
      final exercisesBox = Hive.box<String>('exercises');
      final exercises = <brutl.ExerciseModel>[];
      for (final key in exercisesBox.keys) {
        final jsonString = exercisesBox.get(key);
        if (jsonString == null) continue;
        try {
          final exercise = brutl.ExerciseModel.fromJson(
            jsonDecode(jsonString) as Map<String, dynamic>,
          );
          if (exercise.splitName == widget.dayName) {
            exercises.add(exercise);
          }
        } catch (_) {}
      }
      setState(() => _exercises = exercises);
    } catch (e) {
      debugPrint('EDIT_EXERCISES: Failed to load exercises — $e');
    }
  }

  Future<void> _showRenameDialog(brutl.ExerciseModel exercise) async {
    final controller = TextEditingController(text: exercise.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        title: Text('Rename Exercise', style: AppTextStyles.headingMedium()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              'Save',
              style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == exercise.name) return;
    if (!mounted) return;

    setState(() {
      _exercises = _exercises
          .map((e) => e.id == exercise.id ? e.copyWith(name: newName) : e)
          .toList();
    });

    context.read<WorkoutProvider>().renameExerciseOptimistic(
          widget.dayName,
          exercise.name,
          newName,
        );
    unawaited(_firebaseRenameExercise(exercise, newName));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Exercise renamed to "$newName".'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showDeleteDialog(brutl.ExerciseModel exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.statusError),
        ),
        title: Text(
          'Delete Exercise',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Delete "${exercise.name}" from this day?',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTextStyles.headingSmall(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _exercises = _exercises.where((e) => e.id != exercise.id).toList();
    });

    context.read<WorkoutProvider>().deleteExerciseOptimistic(
          widget.dayName,
          exercise.name,
        );
    unawaited(_firebaseDeleteExercise(exercise));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${exercise.name}" deleted.'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static Future<void> _firebaseRenameExercise(
    brutl.ExerciseModel exercise,
    String newName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final exercisesBox = Hive.box<String>('exercises');
      final updated = exercise.copyWith(name: newName);
      await exercisesBox.put(exercise.id, jsonEncode(updated.toJson()));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .doc(exercise.id)
          .set(
            <String, dynamic>{
              'name': newName,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('EDIT_EXERCISES: Firebase rename exercise failed — $e');
    }
  }

  static Future<void> _firebaseDeleteExercise(
    brutl.ExerciseModel exercise,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final exercisesBox = Hive.box<String>('exercises');
      await exercisesBox.delete(exercise.id);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .doc(exercise.id)
          .delete();
    } catch (e) {
      debugPrint('EDIT_EXERCISES: Firebase delete exercise failed — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, '${widget.dayName} Exercises'),
      body: SafeArea(
        child: _exercises.isEmpty
            ? Center(
                child: Text(
                  'No exercises for this day.',
                  style: AppTextStyles.bodyMedium(),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                itemCount: _exercises.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];
                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusMedium,
                            ),
                            border: Border.all(
                              color: AppColors.borderDefault,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                style: AppTextStyles.headingSmall(),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '${exercise.sets} sets · ${exercise.reps} reps',
                                style: AppTextStyles.bodySmall(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Rename exercise',
                        onPressed: () => _showRenameDialog(exercise),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.statusError,
                          size: 20,
                        ),
                        tooltip: 'Delete exercise',
                        onPressed: () => _showDeleteDialog(exercise),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
