import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/brutl_models.dart';
import '../widgets/exercise_editor_sheet.dart';

/// Firestore-backed workout day detail screen.
///
/// Reads exercises from `users/{uid}/weeks/{weekId}/days/{dayId}` in real-time
/// via a StreamBuilder so updates are reflected immediately.
class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({
    super.key,
    required this.uid,
    required this.weekId,
    required this.dayId,
    required this.workoutName,
  });

  final String uid;
  final String weekId;
  final String dayId;
  final String workoutName;

  DocumentReference<Map<String, dynamic>> get _dayDocRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('weeks')
      .doc(weekId)
      .collection('days')
      .doc(dayId);

  Future<void> _saveExerciseToDay(ExerciseModel exercise) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(_dayDocRef);
      final data = snapshot.data();
      final rawExercises =
          (data?['exercises'] as List<dynamic>?) ?? <dynamic>[];

      final updatedExercises = <Map<String, dynamic>>[];
      var replaced = false;

      for (final rawExercise in rawExercises) {
        if (rawExercise is Map) {
          final exerciseMap = Map<String, dynamic>.from(rawExercise);
          if (exerciseMap['id']?.toString() == exercise.id) {
            updatedExercises.add(exercise.toJson());
            replaced = true;
          } else {
            updatedExercises.add(exerciseMap);
          }
        }
      }

      if (!replaced) {
        updatedExercises.add(exercise.toJson());
      }

      transaction.set(_dayDocRef, <String, dynamic>{
        'exercises': updatedExercises,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _showEditDayNameDialog(
    BuildContext context,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Day'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Day name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updatedName = controller.text.trim();
                if (updatedName.isEmpty) {
                  Navigator.of(dialogContext).pop();
                  return;
                }

                await _dayDocRef.set(<String, dynamic>{
                  'name': updatedName,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _dayDocRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            ),
          );
        }

        final data = snapshot.data?.data();
        final dayName = (data?['name'] as String?)?.trim().isNotEmpty == true
            ? (data?['name'] as String).trim()
            : workoutName;
        final List<dynamic> rawExercises =
            (data?['exercises'] as List<dynamic>?) ?? <dynamic>[];

        final exercises = rawExercises
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    dayName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _showEditDayNameDialog(context, dayName),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // ── Exercise List ──
                Expanded(
                  child: exercises.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.fitness_center,
                                  color: Color(0xFF333333),
                                  size: 64,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No exercises yet',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF666666),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the button below to add your first exercise.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF444444),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            return InkWell(
                              onTap: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => ExerciseEditorSheet(
                                    exercise: exercise,
                                    splitName: dayName,
                                    onSave: _saveExerciseToDay,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF2A2A2A),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exercise.name,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${exercise.sets} sets',
                                          style: const TextStyle(
                                            color: Color(0xFF888888),
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          exercise.reps,
                                          style: const TextStyle(
                                            color: Color(0xFFAAAAAA),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '${exercise.weight.toStringAsFixed(0)} ${exercise.weightUnit}',
                                          style: const TextStyle(
                                            color: Color(0xFF777777),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // ── Add Exercise Button ──
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () async {
                      await showModalBottomSheet<ExerciseModel>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ExerciseEditorSheet(
                          splitName: dayName,
                          onSave: _saveExerciseToDay,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3D00),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Add Exercise'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
