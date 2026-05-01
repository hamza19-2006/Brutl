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

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0A0A0A),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
                ),
              );
            }

            final userData = userSnapshot.data?.data();
            final splitName = (userData?['workoutSplit'] as String?) ??
                (userData?['workoutSplitTemplate'] as String?) ??
                (userData?['split'] as String?) ??
                'Full Body';
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
                      child: MacroDashboardCard(
                        nutrition: nutritionProvider.nutrition,
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
                          final isSelected = workoutProvider.selectedWeek == weekNumber;
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
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: daysForSplit.length,
                        itemBuilder: (context, index) {
                          final day = daysForSplit[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: WorkoutCardWidget(
                              weekId: weekId,
                              dayId: 'day_${index + 1}',
                              dayNumber: day['dayNumber'] as String,
                              workoutName: day['name'] as String,
                              uid: currentUser.uid,
                            ),
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
  switch (splitName) {
    case 'Push/Pull/Legs':
      return <Map<String, dynamic>>[
        {'dayNumber': 'Day 1', 'name': 'Push', 'exercises': 0},
        {'dayNumber': 'Day 2', 'name': 'Pull', 'exercises': 0},
        {'dayNumber': 'Day 3', 'name': 'Legs', 'exercises': 0},
        {'dayNumber': 'Day 4', 'name': 'Push', 'exercises': 0},
        {'dayNumber': 'Day 5', 'name': 'Pull', 'exercises': 0},
        {'dayNumber': 'Day 6', 'name': 'Legs', 'exercises': 0},
      ];
    case 'Bro Split':
      return <Map<String, dynamic>>[
        {'dayNumber': 'Day 1', 'name': 'Chest', 'exercises': 0},
        {'dayNumber': 'Day 2', 'name': 'Back', 'exercises': 0},
        {'dayNumber': 'Day 3', 'name': 'Shoulder', 'exercises': 0},
        {'dayNumber': 'Day 4', 'name': 'Arms', 'exercises': 0},
        {'dayNumber': 'Day 5', 'name': 'Legs', 'exercises': 0},
      ];
    case 'Upper/Lower':
      return <Map<String, dynamic>>[
        {'dayNumber': 'Day 1', 'name': 'Upper A (Chest focused)', 'exercises': 0},
        {'dayNumber': 'Day 2', 'name': 'Lower A (Quad focused)', 'exercises': 0},
        {'dayNumber': 'Day 3', 'name': 'Upper B (Back focused)', 'exercises': 0},
        {'dayNumber': 'Day 4', 'name': 'Lower B (Hamstring focused)', 'exercises': 0},
      ];
    case 'Full Body':
      return <Map<String, dynamic>>[
        {'dayNumber': 'Day 1', 'name': 'Full Body A', 'exercises': 0},
        {'dayNumber': 'Day 2', 'name': 'Full Body B', 'exercises': 0},
        {'dayNumber': 'Day 3', 'name': 'Full Body C', 'exercises': 0},
      ];
    default:
      return <Map<String, dynamic>>[
        {'dayNumber': 'Day 1', 'name': 'Full Body', 'exercises': 0},
      ];
  }
}
