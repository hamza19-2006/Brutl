import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../Screens/steps_history_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// STEPS CARD — Rounded rectangle with linear progress bar
// ═══════════════════════════════════════════════════════════════════════════════

class StepsCard extends StatelessWidget {
  const StepsCard({
    super.key,
    required this.currentSteps,
    required this.goalSteps,
    required this.stepsLabel,
    required this.stepsUnitLabel,
  });

  final int currentSteps;
  final int goalSteps;
  final String stepsLabel;
  final String stepsUnitLabel;

  @override
  Widget build(BuildContext context) {
    final formattedCurrent = NumberFormat.decimalPattern().format(currentSteps);
    final formattedGoal = NumberFormat.decimalPattern().format(goalSteps);
    final safeGoal = goalSteps <= 0 ? 1 : goalSteps;
    final progress = (currentSteps / safeGoal).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const StepsHistoryScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Row(
              children: [
                const Icon(
                  Icons.directions_walk_rounded,
                  color: Color(0xFFFF3D00),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  stepsLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF888888),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Current steps
            Text(
              formattedCurrent,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
            ),
            const SizedBox(height: 2),

            // Goal
            Text(
              '/ $formattedGoal $stepsUnitLabel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 14),

            // Linear progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFF2A2A2A)),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Tap hint
            Row(
              children: [
                Text(
                  'View history',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFF3D00),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFFF3D00),
                  size: 9,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALORIES CARD — Circular progress widget
// ═══════════════════════════════════════════════════════════════════════════════

class CaloriesCard extends StatelessWidget {
  const CaloriesCard({
    super.key,
    required this.caloriesBurned,
    required this.calorieGoal,
    required this.caloriesLabel,
    required this.caloriesUnitLabel,
    required this.onTap,
  });

  final double caloriesBurned;
  final int calorieGoal;
  final String caloriesLabel;
  final String caloriesUnitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final safeGoal = calorieGoal <= 0 ? 1 : calorieGoal;
    final progress = (caloriesBurned / safeGoal).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularPercentIndicator(
              radius: 50,
              lineWidth: 8,
              percent: progress,
              backgroundColor: const Color(0xFF2A2A2A),
              circularStrokeCap: CircularStrokeCap.round,
              linearGradient: const LinearGradient(
                colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
              ),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flame icon
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF3D00),
                    size: 18,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${caloriesBurned.round()}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                  ),
                  Text(
                    '/ $calorieGoal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF666666),
                          fontSize: 9,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caloriesLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF888888),
                    fontSize: 11,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              caloriesUnitLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF555555),
                    fontSize: 9,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
