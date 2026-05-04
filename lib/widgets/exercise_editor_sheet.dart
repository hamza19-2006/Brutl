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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  String _selectedWeightUnit = 'Kg';
  String? _selectedCategoryType;

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
    _weightController = TextEditingController(text: exercise?.weight ?? '');
    _selectedWeightUnit = exercise?.weightUnit ?? 'Kg';
    final existingCategory = exercise?.categoryType.trim() ?? '';
    _selectedCategoryType = existingCategory.isEmpty ? null : existingCategory;
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
    const requiredFieldMessage = 'This field is required';
    final repsPattern = RegExp(r'^\d+(?:\s*,\s*\d+)*$');
    final weightPattern = RegExp(r'^[0-9., ]+$');

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
            child: Form(
              key: _formKey,
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return requiredFieldMessage;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: _setsController,
                    label: ui.setsLabel,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return requiredFieldMessage;
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _EditorField(
                    controller: _repsController,
                    label: ui.repsLabel,
                    keyboardType: TextInputType.text,
                    hintText: 'e.g., 10,8,8,5',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return requiredFieldMessage;
                      }
                      if (!repsPattern.hasMatch(value.trim())) {
                        return 'Enter reps like 10 or 10, 8, 6';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(color: Colors.white),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) {
                              return requiredFieldMessage;
                            }
                            if (!weightPattern.hasMatch(trimmed) ||
                                !RegExp(r'\d').hasMatch(trimmed)) {
                              return 'Only numbers and commas allowed';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Weight',
                            labelStyle: TextStyle(color: Color(0xFF8A8A8A)),
                            hintText: 'Weight',
                            hintStyle: TextStyle(color: Color(0xFF666666)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF2A2A2A)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFFF3D00)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedWeightUnit,
                          dropdownColor: const Color(0xFF1A1A1A),
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            labelStyle: TextStyle(color: Color(0xFF8A8A8A)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF2A2A2A)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFFF3D00)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          iconEnabledColor: const Color(0xFFFF3D00),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                            DropdownMenuItem(
                              value: 'Plates',
                              child: Text('Plates'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedWeightUnit = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryType,
                    dropdownColor: const Color(0xFF1A1A1A),
                    decoration: const InputDecoration(
                      labelText: 'Category Type',
                      labelStyle: TextStyle(color: Color(0xFF8A8A8A)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2A2A2A)),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF3D00)),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    iconEnabledColor: const Color(0xFFFF3D00),
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return requiredFieldMessage;
                      }
                      return null;
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'Compound Exercise',
                        child: Text('Compound Exercise'),
                      ),
                      DropdownMenuItem(
                        value: 'Isolation Exercise',
                        child: Text('Isolation Exercise'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryType = value;
                      });
                    },
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
                        if (!(_formKey.currentState?.validate() ?? false)) {
                          return;
                        }

                        final name = _nameController.text.trim();
                        final sets = int.parse(_setsController.text.trim());
                        final reps = _repsController.text.trim();
                        final normalizedWeight = _weightController.text
                            .split(',')
                            .map((part) => part.trim())
                            .where((part) => part.isNotEmpty)
                            .join(', ');

                        final exerciseToSave = ExerciseModel(
                          id: _isEditMode
                              ? widget.exercise!.id
                              : 'exercise_${DateTime.now().microsecondsSinceEpoch}',
                          name: name,
                          sets: sets,
                          reps: reps,
                          weight: normalizedWeight,
                          categoryType: _selectedCategoryType!.trim(),
                          weightUnit: _selectedWeightUnit,
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
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final String? hintText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
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
