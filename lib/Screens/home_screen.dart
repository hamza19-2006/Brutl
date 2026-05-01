import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'workout_screen.dart';
import '../providers/workout_provider.dart';
import '../services/database_service.dart';
import '../services/step_service.dart';
import '../widgets/biometric_card.dart';
import '../widgets/exercise_highlight_card.dart';
import '../widgets/header_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const List<IconData> _tabIcons = [
    Icons.home_rounded,
    Icons.fitness_center,
    Icons.shopping_bag_rounded,
    Icons.chat_bubble_rounded,
  ];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the user returns from background, trigger pending exercise sync.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPendingExercises();
    }
  }

  /// Syncs any pending exercises created offline to Firestore.
  Future<void> _syncPendingExercises() async {
    try {
      await DatabaseService().syncPendingExercises();
      debugPrint('BRUTL: Pending exercises synced on app resume');
    } catch (e) {
      debugPrint('BRUTL: Failed to sync pending exercises — $e');
    }
  }

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

// ═══════════════════════════════════════════════════════════════════════════════
// HOME TAB — Steps + Calories Dashboard with graceful fallbacks
// ═══════════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onCaloriesTap, required this.onExerciseTap});

  final VoidCallback onCaloriesTap;
  final ValueChanged<String> onExerciseTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, workoutProvider, _) {
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
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser == null
                        ? null
                        : FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 170,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF3D00),
                            ),
                          ),
                        );
                      }

                      final remoteData = snapshot.data?.data();
                      final service = StepService.instance;
                      final serviceSteps = service.getTodaySteps();
                      final serviceCalories = service.calculateCalories(
                        serviceSteps,
                      );
                      final remoteSteps = (remoteData?['dailySteps'] as num?)
                          ?.toInt();
                      final remoteCalories =
                          (remoteData?['dailyCaloriesBurned'] as num?)
                              ?.toDouble();
                      final currentSteps = remoteSteps ?? serviceSteps;
                      final stepGoal = workoutProvider.user.dailyStepGoal;
                      final calories = remoteCalories ?? serviceCalories;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildStepsCard(
                                context,
                                workoutProvider,
                                currentSteps,
                                stepGoal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: CaloriesCard(
                                caloriesBurned: calories.clamp(0, 5000),
                                calorieGoal:
                                    workoutProvider.user.dailyCalorieGoal,
                                caloriesLabel:
                                    workoutProvider.homeUi.caloriesLabel,
                                caloriesUnitLabel:
                                    workoutProvider.homeUi.caloriesUnitLabel,
                                onTap: onCaloriesTap,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // ── Last Workout Section ──
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
                      const SizedBox(height: 12),
                      if (workoutProvider.topVolumeExercises.isEmpty)
                        Text(
                          workoutProvider.noWorkoutMessage,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF666666)),
                        )
                      else
                        ...workoutProvider.topVolumeExercises.map(
                          (exercise) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ExerciseHighlightCard(
                              exercise: exercise,
                              setsLabel: workoutProvider.homeUi.setsLabel,
                              repsLabel: workoutProvider.homeUi.repsLabel,
                              weightLabel: workoutProvider.homeUi.weightLabel,
                              weightUnit: workoutProvider.homeUi.weightUnit,
                              isHighlighted:
                                  exercise.name ==
                                  workoutProvider.highlightedExerciseName,
                              onTap: () => onExerciseTap(exercise.name),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepsCard(
    BuildContext context,
    WorkoutProvider workoutProvider,
    int currentSteps,
    int stepGoal,
  ) {
    return StepsCard(
      currentSteps: currentSteps,
      goalSteps: stepGoal,
      stepsLabel: workoutProvider.homeUi.stepsLabel,
      stepsUnitLabel: workoutProvider.homeUi.stepsUnitLabel,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PLACEHOLDER TABS
// ═══════════════════════════════════════════════════════════════════════════════

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
