import 'package:flutter/material.dart';

import '../models/brutl_models.dart';

class WorkoutDayCard extends StatelessWidget {
  const WorkoutDayCard({
    super.key,
    required this.programDay,
    required this.onTap,
  });

  final ProgramDayModel programDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFFF3D00).withValues(alpha: 0.08),
          highlightColor: const Color(0xFFFF3D00).withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day ${programDay.dayNumber}',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        programDay.splitName,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${programDay.exercises.length} exercise${programDay.exercises.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF555555),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
