import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/macro_dashboard_card.dart';
import '../widgets/meal_logger_sheet.dart';
import '../widgets/workout_card_widget.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key, this.showBottomNavigationBar = true});

  final bool showBottomNavigationBar;

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

        final splitName = workoutProvider.selectedWorkoutSplit;
        final sharedCalories = workoutProvider.currentDailyCaloriesBurned
            .round();
        final syncedNutrition = nutritionProvider.nutrition.copyWith(
          totalCal: sharedCalories,
          goalCal: workoutProvider.user.dailyCalorieGoal,
        );
        final daysForSplit = getDaysForSplit(splitName);
        final weekId = 'week_${workoutProvider.selectedWeek}';

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          bottomNavigationBar: showBottomNavigationBar
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
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data();
                      final firestoreCalories = (data?['calories'] as num?)?.toDouble() ?? 
                          (data?['dailyCaloriesBurned'] as num?)?.toDouble();
                      final calories = (firestoreCalories ?? workoutProvider.currentDailyCaloriesBurned)
                          .clamp(0.0, 5000.0)
                          .round();
                      
                      final streamSyncedNutrition = nutritionProvider.nutrition.copyWith(
                        totalCal: calories,
                        goalCal: workoutProvider.user.dailyCalorieGoal,
                      );

                      return MacroDashboardCard(
                        nutrition: streamSyncedNutrition,
                        ui: nutritionProvider.ui,
                        onTap: () => _openMealLoggerSheet(context),
                      );
                    },
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
