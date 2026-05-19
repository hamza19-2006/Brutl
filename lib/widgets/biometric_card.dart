import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../Screens/steps_history_screen.dart';

class StepsCard extends StatelessWidget {
  const StepsCard({
    super.key,
    required this.currentSteps,
    required this.goalSteps,
    required this.progress,
    required this.stepsLabel,
    required this.stepsUnitLabel,
    this.isLoading = false,
  });

  final int currentSteps;
  final int goalSteps;
  final double progress;
  final String stepsLabel;
  final String stepsUnitLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final formattedCurrent = NumberFormat.decimalPattern().format(currentSteps);
    final formattedGoal = NumberFormat.decimalPattern().format(goalSteps);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StepsHistoryScreen()),
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
            if (isLoading)
              const _CardLoader()
            else ...[
              Text(
                '$formattedCurrent / $formattedGoal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stepsUnitLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF666666),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
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
                        widthFactor: progress.clamp(0.0, 1.0),
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
          ],
        ),
      ),
    );
  }
}

class CaloriesCard extends StatelessWidget {
  const CaloriesCard({
    super.key,
    required this.caloriesBurned,
    required this.calorieGoal,
    required this.progress,
    required this.caloriesLabel,
    required this.caloriesUnitLabel,
    required this.onTap,
    this.isLoading = false,
  });

  final double caloriesBurned;
  final int calorieGoal;
  final double progress;
  final String caloriesLabel;
  final String caloriesUnitLabel;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularPercentIndicator(
              radius: 58,
              lineWidth: 8,
              percent: progress.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF2A2A2A),
              circularStrokeCap: CircularStrokeCap.round,
              linearGradient: const LinearGradient(
                colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
              ),
              center: isLoading
                  ? const _CardLoader()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFF3D00),
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${caloriesBurned.round()}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                        ),
                        Text(
                          '/ $calorieGoal',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF666666),
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              caloriesLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF888888),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              caloriesUnitLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF555555),
                fontSize: 9,
              ),
            ),
            if (!isLoading) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardLoader extends StatelessWidget {
  const _CardLoader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      width: 32,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: const Color(0xFFFF3D00),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
    );
  }
}
