import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

Future<void> saveWorkoutDay({
  required String uid,
  required String weekId,
  required String dayId,
  required List<Map<String, dynamic>> updatedExercisesList,
}) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('weeks')
      .doc(weekId)
      .collection('days')
      .doc(dayId)
      .set(<String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'exercises': updatedExercisesList,
      }, SetOptions(merge: true));
}

class WorkoutCardWidget extends StatelessWidget {
  const WorkoutCardWidget({
    super.key,
    required this.weekId,
    required this.dayId,
    required this.dayNumber,
    required this.workoutName,
    required this.uid,
  });

  final String weekId;
  final String dayId;
  final String dayNumber;
  final String workoutName;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dayNumber,
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF888888),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('weeks')
              .doc(weekId)
              .collection('days')
              .doc(dayId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final bool docExists = snapshot.data?.exists ?? false;
            final String title = (data?['name'] as String?) ?? workoutName;
            final List<dynamic> exercises =
                (data?['exercises'] as List<dynamic>?) ?? <dynamic>[];
            final Timestamp? updatedAt = data?['updatedAt'] as Timestamp?;
            final String updatedLabel = _formatUpdatedAt(updatedAt);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Exercises: ${exercises.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    docExists
                        ? 'Last Updated: $updatedLabel'
                        : 'Last Updated: --',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatUpdatedAt(Timestamp? updatedAt) {
    if (updatedAt == null) {
      return '--';
    }
    return DateFormat('h:mm a').format(updatedAt.toDate());
  }
}
