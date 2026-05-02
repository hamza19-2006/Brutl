import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workout_nutrition_provider.dart';
import '../providers/nutrition_service.dart';
import '../providers/workout_provider.dart';
import '../widgets/macro_dashboard_card.dart';
import '../widgets/workout_card_widget.dart';
import '../models/brutl_models.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, this.showBottomNavigationBar = true});

  final bool showBottomNavigationBar;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  int _caloriesEaten = 0;
  int _calorieGoal = 2000;
  int _carbs = 0;
  int _carbsGoal = 200;
  int _protein = 0;
  int _proteinGoal = 150;
  int _fats = 0;
  int _fatsGoal = 60;

  StreamSubscription<NutritionData>? _nutritionSub;

  @override
  void initState() {
    super.initState();
    _loadNutrition();
  }

  Future<void> _loadNutrition() async {
    final data = await NutritionService.instance.loadTodayNutrition();
    if (!mounted) return;
    setState(() {
      _caloriesEaten = data.caloriesEaten;
      _calorieGoal = data.calorieGoal;
      _carbs = data.carbs;
      _carbsGoal = data.carbsGoal;
      _protein = data.protein;
      _proteinGoal = data.proteinGoal;
      _fats = data.fats;
      _fatsGoal = data.fatsGoal;
    });

    _nutritionSub = NutritionService.instance.stream.listen((data) {
      if (!mounted) return;
      setState(() {
        _caloriesEaten = data.caloriesEaten;
        _calorieGoal = data.calorieGoal;
        _carbs = data.carbs;
        _carbsGoal = data.carbsGoal;
        _protein = data.protein;
        _proteinGoal = data.proteinGoal;
        _fats = data.fats;
        _fatsGoal = data.fatsGoal;
      });
    });
  }

  @override
  void dispose() {
    _nutritionSub?.cancel();
    super.dispose();
  }

  NutritionModel get _builtNutrition => NutritionModel(
    totalCal: _caloriesEaten,
    goalCal: _calorieGoal,
    carbs: MacroNutrientModel(consumed: _carbs, goal: _carbsGoal),
    protein: MacroNutrientModel(consumed: _protein, goal: _proteinGoal),
    fats: MacroNutrientModel(consumed: _fats, goal: _fatsGoal),
    meals: const {},
  );

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

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            ),
          );
        }

        final workoutProvider = context.watch<WorkoutProvider>();
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
                    nutrition: _builtNutrition,
                    ui: nutritionProvider.ui,
                    onTap: () =>
                        _openMealLoggerSheet(context, nutritionProvider),
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
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF3D00),
                          ),
                        );
                      }

                      final data = snapshot.data?.data();
                      List<dynamic> customSplitDays = [];
                      if (data != null && data.containsKey('customSplitDays')) {
                        customSplitDays =
                            data['customSplitDays'] as List<dynamic>;
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

  Future<void> _openMealLoggerSheet(
    BuildContext context,
    WorkoutNutritionProvider provider,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutritionLoggerSheet(
        ui: provider.ui,
        caloriesEaten: _caloriesEaten,
        calorieGoal: _calorieGoal,
      ),
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

class _NutritionLoggerSheet extends StatefulWidget {
  const _NutritionLoggerSheet({
    required this.ui,
    required this.caloriesEaten,
    required this.calorieGoal,
  });

  final WorkoutNutritionUiModel ui;
  final int caloriesEaten;
  final int calorieGoal;

  @override
  State<_NutritionLoggerSheet> createState() => _NutritionLoggerSheetState();
}

class _NutritionLoggerSheetState extends State<_NutritionLoggerSheet> {
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _carbCtrl = TextEditingController();
  final TextEditingController _proCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _calCtrl.dispose();
    _carbCtrl.dispose();
    _proCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.ui.logNutritionTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.ui.todaysTotalPrefix} ${widget.caloriesEaten} ${widget.ui.calorieUnit}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF909090),
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(_calCtrl, 'Calories (kcal)', TextInputType.number),
                const SizedBox(height: 10),
                _buildField(_carbCtrl, 'Carbs (g)', TextInputType.number),
                const SizedBox(height: 10),
                _buildField(_proCtrl, 'Protein (g)', TextInputType.number),
                const SizedBox(height: 10),
                _buildField(_fatCtrl, 'Fats (g)', TextInputType.number),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Opacity(
                    opacity: _isSaving ? 0.55 : 1.0,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3D00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log Nutrition',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    TextInputType type,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8A8A8A)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFF3D00)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _handleLog() async {
    final calories = int.tryParse(_calCtrl.text.trim()) ?? 0;
    final carbs = int.tryParse(_carbCtrl.text.trim()) ?? 0;
    final protein = int.tryParse(_proCtrl.text.trim()) ?? 0;
    final fats = int.tryParse(_fatCtrl.text.trim()) ?? 0;

    if (calories < 0 || carbs < 0 || protein < 0 || fats < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid positive values.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await NutritionService.instance.addCalories(calories, carbs, protein, fats);
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
    }
  }
}
