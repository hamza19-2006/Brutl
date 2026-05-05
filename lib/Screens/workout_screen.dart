import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/workout_nutrition_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/nutrition_service.dart';
import '../services/ai_meal_service.dart';
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
  List<MealData> _meals = [];

  StreamSubscription<NutritionData>? _nutritionSub;

  @override
  void initState() {
    super.initState();
    _loadNutrition();
  }

  Future<void> _loadNutrition() async {
    final data = await NutritionService.instance.loadTodayNutrition();
    if (!mounted) return;
    _applyData(data);

    _nutritionSub = NutritionService.instance.stream.listen((data) {
      if (mounted) _applyData(data);
    });
  }

  void _applyData(NutritionData data) {
    setState(() {
      _caloriesEaten = data.caloriesEaten;
      _calorieGoal = data.calorieGoal;
      _carbs = data.carbs;
      _carbsGoal = data.carbsGoal;
      _protein = data.protein;
      _proteinGoal = data.proteinGoal;
      _fats = data.fats;
      _fatsGoal = data.fatsGoal;
      _meals = data.meals;
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
        final customSplitDays = workoutProvider.customSplitDays;

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
                    onTap: () => _openMealSelectionSheet(context),
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
                                  ? Colors.white
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
                  child: customSplitDays.isEmpty
                      ? Center(
                          child: Text(
                            'No split configured yet.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF888888)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: customSplitDays.length,
                          itemBuilder: (context, index) {
                            final dayName = customSplitDays[index];
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
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Opens the meal selection bottom sheet (Breakfast / Lunch / Snack / Dinner)
  Future<void> _openMealSelectionSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealSelectionSheet(
        meals: _meals,
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

// ─── Meal Selection Sheet ─────────────────────────────────────────────────────

class _MealSelectionSheet extends StatefulWidget {
  const _MealSelectionSheet({
    required this.meals,
    required this.caloriesEaten,
    required this.calorieGoal,
  });

  final List<MealData> meals;
  final int caloriesEaten;
  final int calorieGoal;

  @override
  State<_MealSelectionSheet> createState() => _MealSelectionSheetState();
}

class _MealSelectionSheetState extends State<_MealSelectionSheet> {
  late List<MealData> _meals;

  @override
  void initState() {
    super.initState();
    _meals = List.from(widget.meals);

    // Keep meals in sync with live stream while sheet is open
    NutritionService.instance.stream.listen((data) {
      if (mounted) setState(() => _meals = data.meals);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _meals.fold(0, (sum, m) => sum + m.calories);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 16,
            right: 16,
            top: 12,
          ),
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
                'Log Nutrition',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Today's Total: $total kcal",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF909090)),
              ),
              const SizedBox(height: 16),
              ..._meals.map(
                (meal) => _MealRow(
                  meal: meal,
                  onTap: () => _openLogSheet(context, meal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLogSheet(BuildContext ctx, MealData meal) async {
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutritionLogSheet(meal: meal),
    );
  }
}

// ─── Single Meal Row ──────────────────────────────────────────────────────────

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.onTap});

  final MealData meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    meal.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${meal.calories} kcal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9A9A9A),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFFFF3D00),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nutrition Log Sheet (per meal) ──────────────────────────────────────────

class _NutritionLogSheet extends StatefulWidget {
  const _NutritionLogSheet({required this.meal});

  final MealData meal;

  @override
  State<_NutritionLogSheet> createState() => _NutritionLogSheetState();
}

class _NutritionLogSheetState extends State<_NutritionLogSheet> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _carbCtrl = TextEditingController();
  final TextEditingController _proCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isScanning = false;
  int _scanPhase = 0;
  String? _calorieError;
  Timer? _scanPhaseOneTimer;
  Timer? _scanPhaseTwoTimer;

  static const Duration _scanPhaseOneDuration = Duration(seconds: 2);
  static const Duration _scanPhaseTwoDuration = Duration(seconds: 5);

  static const List<String> _scanMessages = [
    '🚀 Sending image securely...',
    '🧠 AI Analyzing food...',
    '📊 Extracting Macros...',
  ];

  @override
  void dispose() {
    _scanPhaseOneTimer?.cancel();
    _scanPhaseTwoTimer?.cancel();
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
                _buildScanButton(),
                const SizedBox(height: 16),
                Text(
                  widget.meal.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Already logged: ${widget.meal.calories} kcal',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF909090),
                  ),
                ),
                const SizedBox(height: 16),
                _buildField(
                  _calCtrl,
                  'Calories (kcal)',
                  TextInputType.number,
                  errorText: _calorieError,
                ),
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
                    opacity: (_isSaving || _isScanning) ? 0.55 : 1.0,
                    child: ElevatedButton(
                      onPressed: (_isSaving || _isScanning) ? null : _handleLog,
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

  Future<void> _startAiScan() async {
    if (_isSaving || _isScanning) {
      return;
    }

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null || !mounted) {
      return;
    }

    final Uint8List imageBytes = await image.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _isScanning = true;
      _scanPhase = 0;
      _calorieError = null;
    });

    _scanPhaseOneTimer?.cancel();
    _scanPhaseTwoTimer?.cancel();
    _scanPhaseOneTimer = Timer(_scanPhaseOneDuration, () {
      if (mounted && _isScanning) {
        setState(() => _scanPhase = 1);
      }
    });
    _scanPhaseTwoTimer = Timer(_scanPhaseTwoDuration, () {
      if (mounted && _isScanning) {
        setState(() => _scanPhase = 2);
      }
    });

    final result = await analyzeMeal(imageBytes);

    _scanPhaseOneTimer?.cancel();
    _scanPhaseTwoTimer?.cancel();

    if (!mounted) {
      return;
    }

    if (result == null) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not analyze image. Ensure the food is clearly visible and well-lit, then try again.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = false;
      _calCtrl.text = result['kcal']?.toString() ?? '';
      _carbCtrl.text = result['carbs']?.toString() ?? '';
      _proCtrl.text = result['protein']?.toString() ?? '';
      _fatCtrl.text = result['fat']?.toString() ?? '';
    });
  }

  Widget _buildScanButton() {
    if (_isScanning) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF3D00),
            side: const BorderSide(color: Color(0xFFFF3D00), width: 1.5),
            backgroundColor: const Color(0xFFFF3D00).withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey<int>(_scanPhase),
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFFFF3D00),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _scanMessages[_scanPhase],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _startAiScan,
        icon: const Text('📸', style: TextStyle(fontSize: 18)),
        label: const Text(
          'Scan with AI',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF3D00),
          side: const BorderSide(color: Color(0xFFFF3D00), width: 1.5),
          backgroundColor: const Color(0xFFFF3D00).withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    TextInputType type, {
    String? errorText,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        labelStyle: const TextStyle(color: Color(0xFF8A8A8A)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFF3D00)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _handleLog() async {
    final calorieText = _calCtrl.text.trim();
    if (calorieText.isEmpty) {
      setState(() => _calorieError = 'Calories are required');
      return;
    }

    final calories = int.tryParse(calorieText);
    if (calories == null || calories < 0) {
      setState(() => _calorieError = 'Please enter a valid positive number');
      return;
    }

    setState(() => _calorieError = null);

    final carbs = int.tryParse(_carbCtrl.text.trim()) ?? 0;
    final protein = int.tryParse(_proCtrl.text.trim()) ?? 0;
    final fats = int.tryParse(_fatCtrl.text.trim()) ?? 0;

    if (carbs < 0 || protein < 0 || fats < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid positive values for macros.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await NutritionService.instance.addMealCalories(
      mealName: widget.meal.name,
      calories: calories,
      carbs: carbs,
      protein: protein,
      fats: fats,
    );
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
    }
  }
}
