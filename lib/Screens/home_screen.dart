import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'workout_screen.dart';
import '../providers/health_provider.dart';
import '../providers/workout_provider.dart';
import '../services/database_service.dart';
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

    // Wire user weight from Firestore profile into the StepProvider
    // so the calorie formula uses the actual user weight.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncUserWeight();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// When the user returns from background, force-refresh the step count
  /// so the UI is instantly up-to-date without waiting for the stream.
  /// Also triggers pending exercise sync to server.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('BRUTL_STEPS: App resumed — triggering step refresh.');
      context.read<StepProvider>().refreshSteps();
      context.read<StepProvider>().recheckPermissionAndStart();

      // Trigger pending exercise sync on app resume
      _syncPendingExercises();
    }
  }

  /// Syncs any pending exercises created offline to Firestore
  Future<void> _syncPendingExercises() async {
    try {
      await DatabaseService().syncPendingExercises();
      debugPrint('BRUTL: Pending exercises synced on app resume');
    } catch (e) {
      debugPrint('BRUTL: Failed to sync pending exercises — $e');
    }
  }

  /// Reads the user's weight and unit from Firestore and passes it to
  /// StepProvider for the BMR + NEAT calorie calculation.
  Future<void> _syncUserWeight() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final weight = (data['weight'] as num?)?.toDouble() ?? 70.0;
        final unit = data['weightUnit'] as String? ?? 'kg';
        context.read<StepProvider>().setUserWeight(weight, unit);
        debugPrint('BRUTL_STEPS: Synced user weight — $weight $unit');
      }
    } catch (e) {
      debugPrint('BRUTL_STEPS: Failed to load user weight — $e');
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
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // STEPS CARD — with error/permission fallback
                        Expanded(
                          flex: 6,
                          child: _buildStepsCard(
                            context,
                            stepProvider,
                            workoutProvider,
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

  /// Builds the StepsCard with graceful error/permission fallback.
  Widget _buildStepsCard(
    BuildContext context,
    StepProvider stepProvider,
    WorkoutProvider workoutProvider,
  ) {
    // ── Sensor error or permission issue → show fallback card ──
    if (stepProvider.sensorError != null || !stepProvider.hasPermission) {
      return _StepsErrorCard(
        sensorError: stepProvider.sensorError,
        hasPermission: stepProvider.hasPermission,
        permissionPermanentlyDenied: stepProvider.permissionPermanentlyDenied,
        onRequestPermission: () async {
          await stepProvider.recheckPermissionAndStart();
        },
      );
    }

    return StepsCard(
      currentSteps: stepProvider.currentSteps,
      goalSteps: workoutProvider.user.dailyStepGoal,
      stepsLabel: workoutProvider.homeUi.stepsLabel,
      stepsUnitLabel: workoutProvider.homeUi.stepsUnitLabel,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEPS ERROR CARD — Graceful fallback when tracking is unavailable
// ═══════════════════════════════════════════════════════════════════════════════

class _StepsErrorCard extends StatelessWidget {
  const _StepsErrorCard({
    required this.sensorError,
    required this.hasPermission,
    required this.permissionPermanentlyDenied,
    required this.onRequestPermission,
  });

  final String? sensorError;
  final bool hasPermission;
  final bool permissionPermanentlyDenied;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    String message;
    String actionLabel;
    VoidCallback? action;

    if (!hasPermission) {
      message = 'Step tracking paused.\nPermission required.';
      if (permissionPermanentlyDenied) {
        actionLabel = 'Open Settings';
        action = () => openAppSettings();
      } else {
        actionLabel = 'Grant Permission';
        action = onRequestPermission;
      }
    } else {
      message = 'Tracking paused.\nCheck permissions.';
      actionLabel = 'Retry';
      action = onRequestPermission;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFFF6B00).withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Steps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF888888),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFBDBDBD),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (sensorError != null) ...[
            const SizedBox(height: 6),
            Text(
              sensorError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666666),
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton(
              onPressed: action,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF3D00),
                side: const BorderSide(color: Color(0xFFFF3D00)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
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
