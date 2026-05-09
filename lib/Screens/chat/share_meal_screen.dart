import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/nutrition_service.dart';

class ShareMealScreen extends StatefulWidget {
  const ShareMealScreen({super.key});

  @override
  State<ShareMealScreen> createState() => _ShareMealScreenState();
}

class _ShareMealScreenState extends State<ShareMealScreen> {
  NutritionData? _nutrition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await NutritionService.instance.loadTodayNutrition();
    if (mounted) setState(() { _nutrition = data; _isLoading = false; });
  }

  void _shareWholeDay() {
    if (_nutrition == null) return;
    Navigator.pop<Map<String, dynamic>>(context, {
      'mealName': 'Full Day',
      'calories': _nutrition!.caloriesEaten,
      'protein': _nutrition!.protein,
      'carbs': _nutrition!.carbs,
      'fats': _nutrition!.fats,
    });
  }

  void _shareMeal(MealData meal) {
    Navigator.pop<Map<String, dynamic>>(context, {
      'mealName': meal.name,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fats': meal.fats,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Share Meal', style: AppTextStyles.headingLarge()),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accentPrimary))
          : _nutrition == null
              ? Center(
                  child: Text('No nutrition data',
                      style: AppTextStyles.bodyMedium(
                          color: AppColors.textTertiary)),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Whole day card
                    _MealCard(
                      name: 'Whole Day',
                      calories: _nutrition!.caloriesEaten,
                      protein: _nutrition!.protein,
                      carbs: _nutrition!.carbs,
                      fats: _nutrition!.fats,
                      isHighlighted: true,
                      onTap: _shareWholeDay,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Individual Meals',
                        style: AppTextStyles.headingSmall(
                            color: AppColors.textTertiary)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final meal in _nutrition!.meals) ...[
                      _MealCard(
                        name: meal.name,
                        calories: meal.calories,
                        protein: meal.protein,
                        carbs: meal.carbs,
                        fats: meal.fats,
                        onTap: () => _shareMeal(meal),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.onTap,
    this.isHighlighted = false,
  });

  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  final VoidCallback onTap;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isHighlighted
              ? AppColors.accentGlow
              : AppColors.backgroundTertiary,
          border: Border.all(
            color: isHighlighted
                ? AppColors.accentPrimary
                : AppColors.borderDefault,
          ),
          borderRadius:
              BorderRadius.circular(AppSpacing.borderRadiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_rounded,
                    color: isHighlighted
                        ? AppColors.accentPrimary
                        : AppColors.textTertiary,
                    size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(name, style: AppTextStyles.headingSmall()),
                const Spacer(),
                const Icon(Icons.send_rounded,
                    color: AppColors.textTertiary, size: 16),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _Chip('$calories cal'),
                const SizedBox(width: AppSpacing.sm),
                _Chip('P: ${protein}g'),
                const SizedBox(width: AppSpacing.sm),
                _Chip('C: ${carbs}g'),
                const SizedBox(width: AppSpacing.sm),
                _Chip('F: ${fats}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.backgroundQuaternary,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSmall),
      ),
      child: Text(text,
          style: AppTextStyles.labelSmall(color: AppColors.textSecondary)),
    );
  }
}
