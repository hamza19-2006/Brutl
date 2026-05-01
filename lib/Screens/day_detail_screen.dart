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

  DocumentReference<Map<String, dynamic>> get _dayDocRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('weeks')
          .doc(weekId)
          .collection('days')
          .doc(dayId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          workoutName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _dayDocRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            );
          }

          final data = snapshot.data?.data();
          final List<dynamic> rawExercises =
              (data?['exercises'] as List<dynamic>?) ?? <dynamic>[];

          final exercises = rawExercises
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(growable: false);

          return SafeArea(
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
                                    splitName: workoutName,
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
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            ExerciseEditorSheet(splitName: workoutName),
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
          );
        },
      ),
    );
  }
}
