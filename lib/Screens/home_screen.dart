import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/workout_nutrition_provider.dart';
import '../providers/nutrition_service.dart';
import '../providers/workout_provider.dart';
import '../screens/calories_history_screen.dart';
import '../services/calorie_history_service.dart';
import '../services/database_service.dart';
import '../services/step_service.dart';
import '../widgets/biometric_card.dart';
import '../widgets/exercise_highlight_card.dart';
import '../widgets/header_widget.dart';
import 'chat/chat_list_screen.dart';
import 'settings/main_settings_screen.dart';
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
    StepService.instance.initializeStepService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestStepPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// FIX 2: Lifecycle observer now handles BOTH exercise sync AND
  /// the step date-check reset. When the app resumes from background
  /// (e.g. user left it open overnight), both StepService and
  /// StepSensorService are asked to check if the day rolled over.
  /// If it did, they emit 0 immediately — notifyListeners() propagates
  /// to every StreamBuilder/setState so the UI repaints in the same frame.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync pending exercises (existing behaviour)
      _syncPendingExercises();

      // FIX 2: Trigger instant midnight-rollover check on both step services
      _checkStepDateOnResume();
    }
  }

  /// Calls both step services so whichever one is active for this build
  /// correctly resets on resume. Both are no-ops if the day hasn't changed.
  Future<void> _checkStepDateOnResume() async {
    await StepService.instance.checkAndResetIfNewDay();
  }

  Future<void> _syncPendingExercises() async {
    try {
      await DatabaseService().syncPendingExercises();
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
    setState(() => _currentIndex = 1);
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
          _HomeTab(onExerciseTap: _navigateToWorkout),
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
        onTap: (index) => setState(() => _currentIndex = index),
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

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onExerciseTap});

  final ValueChanged<String> onExerciseTap;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int _stepGoal = 10000;
  int _currentSteps = 0;

  int _caloriesEaten = 0;
  int _calorieGoal = 2000;

  StreamSubscription<int>? _stepSub;
  StreamSubscription<NutritionData>? _nutritionSub;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();

    final stepGoal = prefs.getInt('step_goal') ?? 10000;

    // FIX 1: getTodaySteps() now returns 0 on a new day because StepService
    // already ran checkAndResetIfNewDay() during initializeStepService().
    // No stale yesterday count can leak through here.
    final currentSteps = StepService.instance.getTodaySteps();

    final nutrition = await NutritionService.instance.loadTodayNutrition();

    if (!mounted) return;
    setState(() {
      _stepGoal = stepGoal;
      _currentSteps = currentSteps;
      _caloriesEaten = nutrition.caloriesEaten;
      _calorieGoal = nutrition.calorieGoal;
      _isLoading = false;
    });

    unawaited(
      CalorieHistoryService.instance.saveTodayFromNutrition(
        calories: nutrition.caloriesEaten,
        calorieGoal: nutrition.calorieGoal,
        carbs: nutrition.carbs,
        carbsGoal: nutrition.carbsGoal,
        protein: nutrition.protein,
        proteinGoal: nutrition.proteinGoal,
        fats: nutrition.fats,
        fatsGoal: nutrition.fatsGoal,
      ),
    );

    // FIX 3: Stream subscription — any reset (from lifecycle or sensor)
    // emits the new value and setState fires immediately in the same event loop tick.
    _stepSub = StepService.instance.todayStepsStream.listen((steps) {
      if (mounted) setState(() => _currentSteps = steps);
    });

    _nutritionSub = NutritionService.instance.stream.listen((data) {
      if (mounted) {
        setState(() {
          _caloriesEaten = data.caloriesEaten;
          _calorieGoal = data.calorieGoal;
        });
      }
      unawaited(
        CalorieHistoryService.instance.saveTodayFromNutrition(
          calories: data.caloriesEaten,
          calorieGoal: data.calorieGoal,
          carbs: data.carbs,
          carbsGoal: data.carbsGoal,
          protein: data.protein,
          proteinGoal: data.proteinGoal,
          fats: data.fats,
          fatsGoal: data.fatsGoal,
        ),
      );
    });
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _nutritionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final isNutritionLoading = context.select<WorkoutNutritionProvider, bool>(
      (p) => p.isLoading,
    );

    if (workoutProvider.isLoading || isNutritionLoading || _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
      );
    }

    final providerStepGoal = workoutProvider.user.dailyStepGoal;
    final cachedStepGoal = _stepGoal > 0 ? _stepGoal : 10000;
    final safeStepGoal = providerStepGoal > 0
        ? providerStepGoal
        : cachedStepGoal;
    final stepProgress = (_currentSteps / safeStepGoal).clamp(0.0, 1.0);

    final safeCalGoal = _calorieGoal <= 0 ? 2000 : _calorieGoal;
    final calProgress = (_caloriesEaten / safeCalGoal).clamp(0.0, 1.0);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 6,
                      child: StepsCard(
                        currentSteps: _currentSteps,
                        goalSteps: safeStepGoal,
                        progress: stepProgress,
                        stepsLabel: workoutProvider.homeUi.stepsLabel,
                        stepsUnitLabel: workoutProvider.homeUi.stepsUnitLabel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: CaloriesCard(
                        caloriesBurned: _caloriesEaten.toDouble(),
                        calorieGoal: safeCalGoal,
                        progress: calProgress,
                        caloriesLabel: workoutProvider.homeUi.caloriesLabel,
                        caloriesUnitLabel:
                            workoutProvider.homeUi.caloriesUnitLabel,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CaloriesHistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF666666),
                      ),
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
                          onTap: () => widget.onExerciseTap(exercise.name),
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
  }
}

class _ShopTab extends StatelessWidget {
  const _ShopTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      _SimpleTabSurface(icon: Icons.shopping_bag_rounded, label: label);
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return const ChatListScreen();
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
