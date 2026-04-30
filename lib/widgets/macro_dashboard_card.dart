import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../models/brutl_models.dart';

class MacroDashboardCard extends StatelessWidget {
  const MacroDashboardCard({
    super.key,
    required this.nutrition,
    required this.ui,
    required this.onTap,
  });

  final NutritionModel nutrition;
  final WorkoutNutritionUiModel ui;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalProgress = (nutrition.goalCal <= 0
            ? 0
            : nutrition.totalCal / nutrition.goalCal)
        .clamp(0.0, 1.0)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              children: [
                CircularPercentIndicator(
                  radius: 74,
                  lineWidth: 12,
                  animation: true,
                  animateFromLastPercent: true,
                  percent: totalProgress,
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: const Color(0xFF2A2A2A),
                  linearGradient: const LinearGradient(
                    colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
                  ),
                  center: Text(
                    '${nutrition.totalCal} / ${nutrition.goalCal} ${ui.calorieUnit}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniMacroCircle(
                      label: ui.carbsLabel,
                      current: nutrition.carbs.consumed,
                      goal: nutrition.carbs.goal,
                      unit: ui.gramsUnit,
                      progress: nutrition.carbs.progress,
                      progressColor: const Color(0xFF00A3FF),
                    ),
                    _MiniMacroCircle(
                      label: ui.proteinLabel,
                      current: nutrition.protein.consumed,
                      goal: nutrition.protein.goal,
                      unit: ui.gramsUnit,
                      progress: nutrition.protein.progress,
                      progressColor: const Color(0xFF00E676),
                    ),
                    _MiniMacroCircle(
                      label: ui.fatsLabel,
                      current: nutrition.fats.consumed,
                      goal: nutrition.fats.goal,
                      unit: ui.gramsUnit,
                      progress: nutrition.fats.progress,
                      progressColor: const Color(0xFFFFD54F),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMacroCircle extends StatelessWidget {
  const _MiniMacroCircle({
    required this.label,
    required this.current,
    required this.goal,
    required this.unit,
    required this.progress,
    required this.progressColor,
  });

  final String label;
  final int current;
  final int goal;
  final String unit;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 30,
          lineWidth: 5.5,
          animation: true,
          animateFromLastPercent: true,
          percent: progress,
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: const Color(0xFF2A2A2A),
          progressColor: progressColor,
          center: Text(
            '$current/$goal',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF9A9A9A),
            fontSize: 10,
          ),
        ),
        Text(
          unit,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xFF6C6C6C),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
