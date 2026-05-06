import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/brutl_models.dart';
import '../providers/workout_nutrition_provider.dart';
import '../services/ai_meal_service.dart';

class MealLoggerSheet extends StatelessWidget {
  const MealLoggerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutNutritionProvider>(
      builder: (context, provider, _) {
        final ui = provider.ui;
        final nutrition = provider.nutrition;
        final meals = nutrition.meals.entries.toList(growable: false);

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
                      ui.logNutritionTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ui.todaysTotalPrefix} ${nutrition.totalCal} ${ui.calorieUnit}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF909090),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...meals.map(
                      (meal) => _MealRow(
                        mealName: meal.key,
                        calories: meal.value,
                        calorieUnit: ui.calorieUnit,
                        onTap: () => _openMealFlowSheet(
                          context: context,
                          mealName: meal.key,
                          currentCalories: meal.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMealFlowSheet({
    required BuildContext context,
    required String mealName,
    required int currentCalories,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MealFlowSheet(mealName: mealName, currentCalories: currentCalories),
    );
  }
}

class _MealFlowSheet extends StatefulWidget {
  const _MealFlowSheet({required this.mealName, required this.currentCalories});

  final String mealName;
  final int currentCalories;

  @override
  State<_MealFlowSheet> createState() => _MealFlowSheetState();
}

class _MealFlowSheetState extends State<_MealFlowSheet> {
  late final TextEditingController _calorieController;
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatsController = TextEditingController();
  bool _showMacroInput = false;

  // ── AI scan state ──────────────────────────────────────────────────────────
  bool _isScanning = false;
  int _scanPhase = 0; // 0 = sending, 1 = analysing, 2 = extracting
  Timer? _phaseOneTimer;
  Timer? _phaseTwoTimer;

  static const Duration _phaseOneDuration = Duration(seconds: 2);
  static const Duration _phaseTwoDuration = Duration(seconds: 5);

  static const List<String> _scanMessages = [
    '🚀 Sending image securely...',
    '🧠 AI Analyzing food...',
    '📊 Extracting Macros...',
  ];

  @override
  void initState() {
    super.initState();
    _calorieController = TextEditingController(
      text: widget.currentCalories.toString(),
    );
  }

  @override
  void dispose() {
    _phaseOneTimer?.cancel();
    _phaseTwoTimer?.cancel();
    _calorieController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  // ── AI scan logic ──────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final imageBytes = await image.readAsBytes();

    setState(() {
      _isScanning = true;
      _scanPhase = 0;
    });

    _phaseOneTimer?.cancel();
    _phaseTwoTimer?.cancel();
    _phaseOneTimer = Timer(_phaseOneDuration, () {
      if (mounted) setState(() => _scanPhase = 1);
    });
    _phaseTwoTimer = Timer(_phaseTwoDuration, () {
      if (mounted) setState(() => _scanPhase = 2);
    });

    final result = await analyzeMeal(imageBytes);

    _phaseOneTimer?.cancel();
    _phaseTwoTimer?.cancel();

    if (!mounted) return;

    if (result != null) {
      // 1. Automatically save the parsed calories to the provider
      final provider = context.read<WorkoutNutritionProvider>();
      final kcal = result['kcal'] ?? 0;

      await provider.updateMealCalories(
        mealName: widget.mealName,
        calories: kcal,
      );

      if (!mounted) return;

      // 2. Switch UI to show macros immediately and fill the boxes
      setState(() {
        _isScanning = false;
        _showMacroInput = true; // Automatically jump to macro view
        _calorieController.text = kcal.toString();
        _carbsController.text = result['carbs'].toString();
        _proteinController.text = result['protein'].toString();
        _fatsController.text = result['fat'].toString();
      });
    } else {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not analyze image. Ensure the food is clearly visible '
              'and well-lit, then try again.',
            ),
          ),
        );
      }
    }
  }

  Widget _buildScanButton() {
    if (_isScanning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF3D00)),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Color(0xFFFF3D00),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _scanMessages[_scanPhase],
                key: ValueKey<int>(_scanPhase),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _startScan,
        icon: const Text('📸', style: TextStyle(fontSize: 18)),
        label: const Text(
          'Scan with AI',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF3D00),
          side: const BorderSide(color: Color(0xFFFF3D00), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WorkoutNutritionProvider>();
    final ui = provider.ui;
    final nutrition = context.select<WorkoutNutritionProvider, NutritionModel>(
      (value) => value.nutrition,
    );

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

                // Moved the Scan Button UP so it is always visible first
                _buildScanButton(),
                const SizedBox(height: 16),

                if (!_showMacroInput) ...[
                  Text(
                    widget.mealName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _calorieController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '${ui.caloriesLabel} (${ui.calorieUnit})',
                      hintStyle: const TextStyle(color: Color(0xFF6F6F6F)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2A2A2A)),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFFF3D00)),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3D00),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final calories = int.tryParse(
                          _calorieController.text.trim(),
                        );
                        if (calories == null || calories < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ui.invalidInputMessage)),
                          );
                          return;
                        }
                        await provider.updateMealCalories(
                          mealName: widget.mealName,
                          calories: calories,
                        );
                        if (mounted) {
                          setState(() {
                            _showMacroInput = true;
                          });
                        }
                      },
                      child: Text(ui.saveActionLabel),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Add Macros for ${widget.mealName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MacroInputBlock(
                    label: ui.carbsLabel,
                    currentValue: nutrition.carbs.consumed,
                    controller: _carbsController,
                    hintText: 'Add Carbs (${ui.gramsUnit})',
                  ),
                  const SizedBox(height: 10),
                  _MacroInputBlock(
                    label: ui.proteinLabel,
                    currentValue: nutrition.protein.consumed,
                    controller: _proteinController,
                    hintText: 'Add Protein (${ui.gramsUnit})',
                  ),
                  const SizedBox(height: 10),
                  _MacroInputBlock(
                    label: ui.fatsLabel,
                    currentValue: nutrition.fats.consumed,
                    controller: _fatsController,
                    hintText: 'Add Fats (${ui.gramsUnit})',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3D00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final carbs =
                            int.tryParse(_carbsController.text.trim()) ?? 0;
                        final protein =
                            int.tryParse(_proteinController.text.trim()) ?? 0;
                        final fats =
                            int.tryParse(_fatsController.text.trim()) ?? 0;

                        if (carbs < 0 || protein < 0 || fats < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ui.invalidInputMessage)),
                          );
                          return;
                        }

                        await provider.addMealMacros(
                          carbs: carbs,
                          protein: protein,
                          fats: fats,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Confirm Macros'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MacroInputBlock extends StatelessWidget {
  const _MacroInputBlock({
    required this.label,
    required this.currentValue,
    required this.controller,
    required this.hintText,
  });

  final String label;
  final int currentValue;
  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Current Total: ${currentValue}g',
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF6F6F6F)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2A2A2A)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFF3D00)),
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({
    required this.mealName,
    required this.calories,
    required this.calorieUnit,
    required this.onTap,
  });

  final String mealName;
  final int calories;
  final String calorieUnit;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    mealName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$calories $calorieUnit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9A9A9A),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Color(0xFFFF3D00),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
