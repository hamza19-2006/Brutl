import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/brutl_models.dart';

class ExerciseCardWidget extends StatelessWidget {
  const ExerciseCardWidget({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  final ExerciseModel exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repsDisplay = exercise.reps.trim().isEmpty ? '--' : exercise.reps;

    final weightDisplay = (exercise.weight <= 0)
        ? '--'
        : exercise.weight % 1 == 0
        ? exercise.weight.toStringAsFixed(0)
        : exercise.weight.toString();

    final unit = exercise.weightUnit.trim().isEmpty
        ? 'Kg'
        : exercise.weightUnit;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 65,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sets: ${exercise.sets}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reps: $repsDisplay',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Weight box — tight padding, same font size
            Align(
              alignment: Alignment.centerRight,
              child: IntrinsicWidth(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF242424),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF333333),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        weightDisplay,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        unit,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
