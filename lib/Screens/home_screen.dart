import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'workout_screen.dart';
import '../providers/health_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/biometric_card.dart';
import '../widgets/exercise_highlight_card.dart';
import '../widgets/header_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<IconData> _tabIcons = [
    Icons.home_rounded,
    Icons.fitness_center,
    Icons.shopping_bag_rounded,
    Icons.chat_bubble_rounded,
  ];
  int _currentIndex = 0;

  void _navigateToWorkout([String? highlightedExercise]) {
    context.read<WorkoutProvider>().setHighlightedExercise(highlightedExercise);
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final navLabels = context.select<WorkoutProvider, List<String>>(
      (provider) => provider.homeUi.navigationLabels,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            onCaloriesTap: () => _navigateToWorkout(),
            onExerciseTap: _navigateToWorkout,
          ),
          const WorkoutScreen(showBottomNavigationBar: false),
          _ShopTab(label: navLabels[2]),
          _ChatTab(label: navLabels[3]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        showUnselectedLabels: true,
        showSelectedLabels: true,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedItemColor: const Color(0xFFFF3D00),
        unselectedItemColor: const Color(0xFF555555),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: List.generate(
          _tabIcons.length,
          (index) => BottomNavigationBarItem(
            icon: Icon(_tabIcons[index]),
            label: navLabels[index],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onCaloriesTap, required this.onExerciseTap});

  final VoidCallback onCaloriesTap;
  final ValueChanged<String> onExerciseTap;

  @override
  Widget build(BuildContext context) {
    return Consumer2<WorkoutProvider, StepProvider>(
      builder: (context, workoutProvider, stepProvider, _) {
        if (workoutProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            child: Column(
              children: [
                HeaderWidget(
                  user: workoutProvider.user,
                  workoutName: workoutProvider.todayWorkoutName,
                  daySuffix: workoutProvider.homeUi.daySuffix,
                  now: DateTime.now(),
                  brandName: workoutProvider.homeUi.brandName,
                ),
                const SizedBox(height: 20),

                // ── Split Dashboard: Steps (left) + Calories (right) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // STEPS CARD — taps to StepsHistoryScreen
                      Expanded(
                        flex: 6,
                        child: StepsCard(
                          currentSteps: stepProvider.currentSteps,
                          goalSteps: workoutProvider.user.dailyStepGoal,
                          stepsLabel: workoutProvider.homeUi.stepsLabel,
                          stepsUnitLabel: workoutProvider.homeUi.stepsUnitLabel,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // CALORIES CARD — taps to Workout tab
                      Expanded(
                        flex: 4,
                        child: CaloriesCard(
                          caloriesBurned: stepProvider.caloriesBurned,
                          calorieGoal: workoutProvider.user.dailyCalorieGoal,
                          caloriesLabel: workoutProvider.homeUi.caloriesLabel,
                          caloriesUnitLabel:
                              workoutProvider.homeUi.caloriesUnitLabel,
                          onTap: onCaloriesTap,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workoutProvider.lastWorkoutTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workoutProvider.lastWorkoutSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (workoutProvider.topVolumeExercises.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2A2A2A),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      workoutProvider.noWorkoutMessage,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  )
                else
                  ...workoutProvider.topVolumeExercises.map(
                    (exercise) => ExerciseHighlightCard(
                      exercise: exercise,
                      setsLabel: workoutProvider.homeUi.setsLabel,
                      repsLabel: workoutProvider.homeUi.repsLabel,
                      weightLabel: workoutProvider.homeUi.weightLabel,
                      weightUnit: workoutProvider.homeUi.weightUnit,
                      isHighlighted:
                          workoutProvider.highlightedExerciseName ==
                          exercise.name,
                      onTap: () => onExerciseTap(exercise.name),
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

class _ShopTab extends StatelessWidget {
  const _ShopTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _SimpleTabSurface(icon: Icons.shopping_bag_rounded, label: label);
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _SimpleTabSurface(icon: Icons.chat_bubble_rounded, label: label);
  }
}

class _SimpleTabSurface extends StatelessWidget {
  const _SimpleTabSurface({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFF3D00), size: 34),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
