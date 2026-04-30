import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/macro_dashboard_card.dart';
import '../widgets/meal_logger_sheet.dart';
import '../widgets/workout_day_card.dart';
import 'workout_detail_screen.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key, this.showBottomNavigationBar = true});

  final bool showBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutNutritionProvider>(
      builder: (context, provider, _) {
        final ui = provider.ui;

        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            ),
          );
        }

        final workoutProvider = context.watch<WorkoutProvider>();
        final currentWeekWorkouts = workoutProvider.currentWeekWorkouts;
        
        return Scaffold(
          backgroundColor: const Color(0xFF0A0A0A),
          bottomNavigationBar: showBottomNavigationBar
              ? BottomNavigationBar(
                  currentIndex: provider.bottomNavIndex,
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: const Color(0xFF111111),
                  selectedItemColor: const Color(0xFFFF3D00),
                  unselectedItemColor: const Color(0xFF5A5A5A),
                  selectedFontSize: 10,
                  unselectedFontSize: 10,
                  items: List.generate(
                    ui.bottomNavigationLabels.length,
                    (index) => BottomNavigationBarItem(
                      icon: Icon(_iconForIndex(index)),
                      label: ui.bottomNavigationLabels[index],
                    ),
                  ),
                  onTap: provider.setBottomNavIndex,
                )
              : null,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Text(
                      ui.screenTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: MacroDashboardCard(
                    nutrition: provider.nutrition,
                    ui: ui,
                    onTap: () => _openMealLoggerSheet(context),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                
                // --- PHASE 3: THE WEEK SCROLLER ---
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 45,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: workoutProvider.totalProgramWeeks,
                      itemBuilder: (context, index) {
                        final weekNum = index + 1;
                        final isSelected = workoutProvider.selectedWeek == weekNum;
                        return GestureDetector(
                          onTap: () => workoutProvider.selectWeek(weekNum),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF3D00) : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected ? null : Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Text(
                              'Week $weekNum',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFF888888),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                
                // --- PHASE 4: THE DAY CARDS ---
                if (currentWeekWorkouts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          "No workouts scheduled for this week. Tap '+' to build your split.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF888888),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: currentWeekWorkouts.length,
                      itemBuilder: (context, index) {
                        final session = currentWeekWorkouts[index];
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: WorkoutDayCard(
                            key: ValueKey(session.id),
                            programDay: session,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WorkoutDetailScreen(session: session),
                                ),
                              ).then((_) {
                                // Refresh logic if needed
                              });
                            },
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
