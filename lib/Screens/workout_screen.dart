import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/brutl_models.dart';
import '../providers/workout_nutrition_provider.dart';
import '../widgets/exercise_editor_sheet.dart';
import '../widgets/macro_dashboard_card.dart';
import '../widgets/meal_logger_sheet.dart';

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

        final selectedSplit = provider.selectedSplit;
        final splitLastUpdated = provider.currentSplitModel.updatedAt;
        final splitNames = provider.selectedSession.splits
            .map((split) => split.title)
            .toList(growable: false);
        final exercises = provider.filteredExercises;

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
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _WorkoutControlHeaderDelegate(
                    child: _WorkoutControlHeader(
                      ui: ui,
                      sessions: provider.sessions,
                      selectedSessionId: provider.selectedSessionId,
                      splitNames: splitNames,
                      selectedSplit: provider.selectedSplit,
                      onSessionChanged: provider.selectSession,
                      onSplitChanged: (splitName) {
                        context
                            .read<WorkoutNutritionProvider>()
                            .setSelectedSplit(splitName);
                      },
                      onAddExercise: () => _openExerciseEditor(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedSplit,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatLastUpdated(splitLastUpdated),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[400],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (exercises.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(
                                      0xFFFF3D00,
                                    ).withValues(alpha: 0.15),
                                    const Color(
                                      0xFFFF6B00,
                                    ).withValues(alpha: 0.05),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.fitness_center_rounded,
                                color: Color(0xFFFF3D00),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Your log is empty. Tap + to add an exercise!',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        return _ExerciseCard(
                          exercise: exercise,
                          ui: ui,
                          onTap: () =>
                              _openExerciseEditor(context, exercise: exercise),
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

  Future<void> _openExerciseEditor(
    BuildContext context, {
    ExerciseModel? exercise,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseEditorSheet(exercise: exercise),
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

  String _formatLastUpdated(DateTime updatedAt) {
    if (updatedAt.millisecondsSinceEpoch <= 0) {
      return 'Last Updated: Waiting for your first sync';
    }

    final now = DateTime.now();
    final isToday =
        now.year == updatedAt.year &&
        now.month == updatedAt.month &&
        now.day == updatedAt.day;
    if (isToday) {
      return 'Last Updated: Today at ${DateFormat('h:mm a').format(updatedAt)}';
    }
    return 'Last Updated: ${DateFormat('MMM d, y').format(updatedAt)}';
  }
}

class _WorkoutControlHeader extends StatelessWidget {
  const _WorkoutControlHeader({
    required this.ui,
    required this.sessions,
    required this.selectedSessionId,
    required this.splitNames,
    required this.selectedSplit,
    required this.onSessionChanged,
    required this.onSplitChanged,
    required this.onAddExercise,
  });

  final WorkoutNutritionUiModel ui;
  final List<WorkoutSessionModel> sessions;
  final String selectedSessionId;
  final List<String> splitNames;
  final String selectedSplit;
  final ValueChanged<String> onSessionChanged;
  final ValueChanged<String> onSplitChanged;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ui.workoutHistoryTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SessionDropdown(
                sessions: sessions,
                selectedSessionId: selectedSessionId,
                onChanged: onSessionChanged,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onAddExercise,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF3D00),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              textStyle: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            child: Text(ui.addNewExerciseLabel),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: splitNames
                    .map((splitName) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selectedSplit == splitName,
                          onSelected: (_) => onSplitChanged(splitName),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          label: Text(splitName),
                          side: const BorderSide(color: Color(0xFF2A2A2A)),
                          selectedColor: const Color(0xFFFF3D00),
                          backgroundColor: const Color(0xFF1A1A1A),
                          labelStyle: TextStyle(
                            color: selectedSplit == splitName
                                ? Colors.white
                                : const Color(0xFFC4C4C4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionDropdown extends StatelessWidget {
  const _SessionDropdown({
    required this.sessions,
    required this.selectedSessionId,
    required this.onChanged,
  });

  final List<WorkoutSessionModel> sessions;
  final String selectedSessionId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSessionId,
          dropdownColor: const Color(0xFF1A1A1A),
          iconEnabledColor: const Color(0xFF9A9A9A),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white),
          items: sessions
              .map(
                (session) => DropdownMenuItem<String>(
                  value: session.id,
                  child: Text(session.title),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onChanged(value);
          },
        ),
      ),
    );
  }
}

class _WorkoutControlHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _WorkoutControlHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 176;

  @override
  double get maxExtent => 176;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _WorkoutControlHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.ui,
    required this.onTap,
  });

  final ExerciseModel exercise;
  final WorkoutNutritionUiModel ui;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repsText = exercise.reps;
    final isWholeWeight = exercise.weight == exercise.weight.truncateToDouble();
    final weightText = isWholeWeight
        ? exercise.weight.toStringAsFixed(0)
        : exercise.weight.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${ui.setsLabel}: ${exercise.sets}   ${ui.repsLabel}: $repsText',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF989898),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 85.0,
                  height: 40.0,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$weightText${ui.weightUnit}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
