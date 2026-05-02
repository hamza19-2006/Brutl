import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Local preferences access.

import '../providers/workout_nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../services/database_service.dart';
import '../services/step_service.dart';
import '../widgets/biometric_card.dart';
import '../widgets/exercise_highlight_card.dart';
import '../widgets/header_widget.dart';
import 'workout_screen.dart';

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
    
    // Initialize StepService safely AFTER HomeScreen begins loading
    StepService.instance.initializeStepService(); // Start step tracking.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestStepPermission();
    });
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

  Future<void> requestStepPermission() async {
    var status = await Permission.activityRecognition.status;

    if (status.isDenied) {
      status = await Permission.activityRecognition.request();
    }

    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Activity Permission Required'),
            content: const Text(
              'Step counting needs physical activity permission. '
              'Please enable it in app settings to track your daily steps.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Not Now'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );
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

class _HomeLocalData { // Holds locally stored dashboard data.
  const _HomeLocalData({ // Creates local data snapshot.
    required this.stepGoal, // Daily step goal from prefs.
    required this.calorieGoal, // Daily calorie goal from prefs.
    required this.todayCalories, // Today's calories from prefs.
  }); // End constructor.

  final int stepGoal; // Step goal value.
  final int calorieGoal; // Calorie goal value.
  final int todayCalories; // Today's calories value.
} // End local data model.

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onCaloriesTap, required this.onExerciseTap});

  final VoidCallback onCaloriesTap;
  final ValueChanged<String> onExerciseTap;

  @override
  Widget build(BuildContext context) {
    return Consumer2<WorkoutProvider, WorkoutNutritionProvider>(
      builder: (context, workoutProvider, nutritionProvider, _) {
        if (workoutProvider.isLoading || nutritionProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
          );
        }

        return FutureBuilder<_HomeLocalData>(
          future: _loadLocalData(), // Load shared preferences values.
          builder: (context, snapshot) {
            final localData = snapshot.data ?? // Use snapshot data or fallback.
                const _HomeLocalData( // Default fallback values.
                  stepGoal: 0, // Default step goal.
                  calorieGoal: 0, // Default calorie goal.
                  todayCalories: 0, // Default calorie total.
                ); // End fallback instance.

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
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildStepsCard(
                                context,
                                workoutProvider,
                                localData.stepGoal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: _buildCaloriesCard(
                                context,
                                workoutProvider,
                                localData.calorieGoal,
                                localData.todayCalories,
                              ),
                            ),
                          ],
                        ),
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
      },
    );
  }

  Widget _buildStepsCard(
    BuildContext context,
    WorkoutProvider workoutProvider,
    int stepGoal,
  ) {
    return StreamBuilder<int>(
      stream: StepService.instance.todayStepsStream, // Listen to today steps.
      initialData: StepService.instance.getTodaySteps(), // Seed with cache.
      builder: (context, snapshot) {
        final todaySteps = snapshot.data ?? 0; // Default when stream is empty.

        return StepsCard(
          currentSteps: todaySteps,
          goalSteps: stepGoal,
          stepsLabel: workoutProvider.homeUi.stepsLabel,
          stepsUnitLabel: workoutProvider.homeUi.stepsUnitLabel,
        );
      },
    );
  }

  Widget _buildCaloriesCard(
    BuildContext context,
    WorkoutProvider workoutProvider,
    int calorieGoal,
    int todayCalories,
  ) {
    final clampedCalories = _clampCalories(todayCalories); // Clamp daily calories.

    return CaloriesCard(
      caloriesBurned: clampedCalories.toDouble(),
      calorieGoal: calorieGoal,
      caloriesLabel: workoutProvider.homeUi.caloriesLabel,
      caloriesUnitLabel: workoutProvider.homeUi.caloriesUnitLabel,
      onTap: onCaloriesTap,
    );
  }

  Future<_HomeLocalData> _loadLocalData() async { // Load prefs data for cards.
    final prefs = await SharedPreferences.getInstance(); // Read preferences.
    final stepGoal = prefs.getInt('step_goal') ?? 0; // Read step goal.
    final calorieGoal = prefs.getInt('calorie_goal') ?? 0; // Read calorie goal.
    final todayCalories = prefs.getInt('today_calories') ?? 0; // Read today calories.
    return _HomeLocalData(
      stepGoal: stepGoal,
      calorieGoal: calorieGoal,
      todayCalories: _clampCalories(todayCalories),
    );
  }

  int _clampCalories(int calories) { // Clamp calories to 0..5000.
    if (calories < 0) { // Guard negative calories.
      return 0; // Clamp to zero.
    }
    if (calories > 5000) { // Guard upper bound.
      return 5000; // Clamp to max.
    }
    return calories; // Return normalized calories.
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
