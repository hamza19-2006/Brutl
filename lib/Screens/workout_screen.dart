import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences access.

import '../providers/workout_nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/macro_dashboard_card.dart';
import '../widgets/meal_logger_sheet.dart';
import '../widgets/workout_card_widget.dart';

class WorkoutScreen extends StatefulWidget { // Workout screen widget.
  const WorkoutScreen({super.key, this.showBottomNavigationBar = true});

  final bool showBottomNavigationBar;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState(); // Create state.
}

class _WorkoutScreenState extends State<WorkoutScreen> { // Stateful workout screen.
  int _lastSeenMealCalories = 0; // Tracks last seen meal calories.
  bool _hasInitializedCalories = false; // Tracks initial sync.
  int? _pendingCaloriesTotal; // Guards duplicate sync scheduling.
  bool _isSyncScheduled = false; // Prevents duplicate frame scheduling.

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutNutritionProvider>(
      builder: (context, nutritionProvider, _) {
        if (nutritionProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            ),
          );
        }

        final workoutProvider = context.watch<WorkoutProvider>();
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            ),
          );
        }

        final splitName = workoutProvider.selectedWorkoutSplit; // Selected split name.
        final nutrition = nutritionProvider.nutrition; // Current nutrition model.
        _scheduleCaloriesSync(nutrition.totalCal); // Sync today_calories locally.
        final syncedNutrition = nutrition.copyWith( // Clamp displayed calories.
          totalCal: _clampCalories(nutrition.totalCal), // Clamp total calories.
        );
        final daysForSplit = getDaysForSplit(splitName);
        final weekId = 'week_${workoutProvider.selectedWeek}';

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          bottomNavigationBar: widget.showBottomNavigationBar
              ? BottomNavigationBar(
                  currentIndex: nutritionProvider.bottomNavIndex,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: const Color(0xFF111111),
                  selectedItemColor: const Color(0xFFFF3D00),
                  unselectedItemColor: const Color(0xFF5A5A5A),
                  selectedFontSize: 10,
                  unselectedFontSize: 10,
                  items: List.generate(
                    nutritionProvider.ui.bottomNavigationLabels.length,
                    (index) => BottomNavigationBarItem(
                      icon: Icon(_iconForIndex(index)),
                      label: nutritionProvider.ui.bottomNavigationLabels[index],
                    ),
                  ),
                  onTap: nutritionProvider.setBottomNavIndex,
                )
              : null,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Text(
                    nutritionProvider.ui.screenTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MacroDashboardCard(
                    nutrition: syncedNutrition,
                    ui: nutritionProvider.ui,
                    onTap: () => _openMealLoggerSheet(context),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: workoutProvider.totalProgramWeeks,
                    itemBuilder: (context, index) {
                      final weekNumber = index + 1;
                      final isSelected =
                          workoutProvider.selectedWeek == weekNumber;
                      return GestureDetector(
                        onTap: () => workoutProvider.selectWeek(weekNumber),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF3D00)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Text(
                            'Week $weekNumber',
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF888888),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
                        );
                      }

                      final data = snapshot.data?.data();
                      List<dynamic> customSplitDays = [];
                      if (data != null && data.containsKey('customSplitDays')) {
                        customSplitDays = data['customSplitDays'] as List<dynamic>;
                      }

                      if (customSplitDays.isEmpty) {
                        customSplitDays = ['Full Body'];
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: customSplitDays.length,
                        itemBuilder: (context, index) {
                          final dayName = customSplitDays[index].toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: WorkoutCardWidget(
                              weekId: weekId,
                              dayId: 'day_${index + 1}',
                              dayNumber: 'Day ${index + 1}',
                              workoutName: dayName,
                              uid: currentUser.uid,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMealLoggerSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MealLoggerSheet(),
    );
  }

  /// Schedules a post-frame sync to avoid updating prefs during build. // Explain scheduling.
  void _scheduleCaloriesSync(int currentMealCalories) { // Schedule local calories sync.
    _pendingCaloriesTotal = currentMealCalories; // Track pending total.
    if (_isSyncScheduled) { // Skip if already scheduled.
      return; // Exit early.
    }
    _isSyncScheduled = true; // Mark as scheduled.
    WidgetsBinding.instance.addPostFrameCallback((_) { // Defer to after frame.
      _isSyncScheduled = false; // Clear scheduled flag.
      final pendingTotal = _pendingCaloriesTotal; // Capture latest total.
      _pendingCaloriesTotal = null; // Clear pending total.
      if (!mounted) { // Guard unmounted state.
        return; // Exit early.
      }
      if (pendingTotal == null) { // Guard missing total.
        return; // Exit early.
      }
      _syncTodayCalories(pendingTotal); // Persist calories.
    });
  }

  Future<void> _syncTodayCalories(int currentMealCalories) async { // Persist today calories.
    if (!_hasInitializedCalories) { // Skip initial sync.
      _hasInitializedCalories = true; // Mark initialized.
      _lastSeenMealCalories = currentMealCalories; // Seed last calories.
      return; // Exit early.
    }

    final delta = currentMealCalories - _lastSeenMealCalories; // Calculate delta.
    _lastSeenMealCalories = currentMealCalories; // Update last total.
    if (delta <= 0) { // Ignore non-positive deltas.
      return; // Exit early.
    }

    final prefs = await SharedPreferences.getInstance(); // Load preferences.
    final existing = prefs.getInt('today_calories') ?? 0; // Read current total.
    final updated = existing + delta; // Add delta calories.
    final clamped = _clampCalories(updated); // Clamp to 0..5000.
    await prefs.setInt('today_calories', clamped); // Persist updated total.
    if (mounted) { // Guard mounted state.
      setState(() {}); // Refresh UI.
    }
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

  IconData _iconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.home_rounded;
      case 1:
        return Icons.fitness_center;
      case 2:
        return Icons.shopping_bag_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }
}

List<Map<String, dynamic>> getDaysForSplit(String splitName) {
  final normalized = splitName.trim().toLowerCase();

  List<String> dayNames;
  switch (normalized) {
    case 'push pull legs':
    case 'push/pull/legs':
    case 'push, pull, legs':
    case 'push, pull, legs, repeat':
    case 'ppl':
      dayNames = <String>[
        'Push (Chest, Shoulders, Triceps)',
        'Pull (Back, Biceps, Rear Delts)',
        'Legs (Quads, Hamstrings, Calves)',
        'Push (Chest, Shoulders, Triceps)',
        'Pull (Back, Biceps, Rear Delts)',
        'Legs (Quads, Hamstrings, Calves)',
      ];
      break;
    case 'bro split':
    case 'bro split (1 muscle per day)':
      dayNames = <String>['Chest', 'Back', 'Shoulders', 'Arms', 'Legs'];
      break;
    case 'upper/lower':
    case 'upper lower':
    case 'upper, lower, rest, repeat':
      dayNames = <String>['Upper A', 'Lower A', 'Upper B', 'Lower B'];
      break;
    case 'full body':
      dayNames = <String>['Full Body'];
      break;
    default:
      dayNames = <String>['Full Body'];
      break;
  }

  return List<Map<String, dynamic>>.generate(
    dayNames.length,
    (index) => <String, dynamic>{
      'dayNumber': 'Day ${index + 1}',
      'name': dayNames[index],
      'exercises': 0,
    },
  );
}
