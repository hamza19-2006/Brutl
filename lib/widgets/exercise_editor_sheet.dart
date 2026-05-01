import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/brutl_models.dart';
import '../providers/workout_nutrition_provider.dart';
import '../services/database_service.dart';

class ExerciseEditorSheet extends StatefulWidget {
  const ExerciseEditorSheet({
    super.key,
    this.exercise,
    required this.splitName,
    this.onSave,
  });

  final ExerciseModel? exercise;
  final String splitName;
  final Future<void> Function(ExerciseModel exercise)? onSave;

  @override
  State<ExerciseEditorSheet> createState() => _ExerciseEditorSheetState();
}

class _ExerciseEditorSheetState extends State<ExerciseEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;

  bool get _isEditMode => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _nameController = TextEditingController(text: exercise?.name ?? '');
    _setsController = TextEditingController(
      text: (exercise?.sets ?? 4).toString(),
    );
    _repsController = TextEditingController(text: exercise?.reps ?? '10');
    _weightController = TextEditingController(
      text: (exercise?.weight ?? 20).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutNutritionProvider>();
    final ui = provider.ui;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditMode ? ui.editExerciseTitle : ui.addExerciseTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _EditorField(
                  controller: _nameController,
                  label: ui.exerciseNameLabel,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 10),
                _EditorField(
                  controller: _setsController,
                  label: ui.setsLabel,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _EditorField(
                  controller: _repsController,
                  label: ui.repsLabel,
                  keyboardType: TextInputType.text,
                  hintText: 'e.g., 10,8,8,5',
                ),
                const SizedBox(height: 10),
                _EditorField(
                  controller: _weightController,
                  label: '${ui.weightLabel} (${ui.weightUnit})',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3D00),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      final sets = int.tryParse(_setsController.text.trim());
                      final reps = _repsController.text.trim();
                      final weight = double.tryParse(
                        _weightController.text.trim(),
                      );
                      final repsPattern = RegExp(r'^\d+(?:\s*,\s*\d+)*$');

                      if (name.isEmpty ||
                          sets == null ||
                          sets <= 0 ||
                          !repsPattern.hasMatch(reps) ||
                          weight == null ||
                          weight < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ui.invalidInputMessage)),
                        );
                        return;
                      }

                      final exerciseToSave = ExerciseModel(
                        id: _isEditMode
                            ? widget.exercise!.id
                            : 'exercise_${DateTime.now().microsecondsSinceEpoch}',
                        name: name,
                        sets: sets,
                        reps: reps,
                        weight: weight,
                        splitName: widget.splitName,
                      );

                      if (widget.onSave != null) {
                        await widget.onSave!(exerciseToSave);
                      } else {
                        await DatabaseService().saveExercise(exerciseToSave);
                      }

                      if (context.mounted) {
                        Navigator.of(context).pop(exerciseToSave);
                      }
                    },
                    child: Text(ui.saveActionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    required this.keyboardType,
    this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8A8A8A)),
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF666666)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFF3D00)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
