// ═══════════════════════════════════════════════════════════════════════════════
// CALORIES HISTORY SCREEN — with Water Tracking
// ═══════════════════════════════════════════════════════════════════════════════
// Replace lib/Screens/calories_history_screen.dart with this file entirely.

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/brutl_user_provider.dart';
import '../providers/nutrition_service.dart';
import '../providers/water_provider.dart';
import '../services/calorie_history_service.dart';

class CaloriesHistoryScreen extends StatefulWidget {
  const CaloriesHistoryScreen({super.key});

  @override
  State<CaloriesHistoryScreen> createState() => _CaloriesHistoryScreenState();
}

class _CaloriesHistoryScreenState extends State<CaloriesHistoryScreen>
    with SingleTickerProviderStateMixin {
  int _weekOffset = 0;
  late int _selectedDayIndex;

  Map<String, DailyMacroSnapshot?> _weekData = {};
  bool _isLoading = true;

  int _calorieGoal = 2000;
  int _carbsGoal = 200;
  int _proteinGoal = 150;
  int _fatsGoal = 60;

  late final AnimationController _animCtrl;
  late final Animation<double> _animCurve;

  bool _barsVisible = false;

  StreamSubscription<NutritionData>? _nutritionSub;

  // Water data per day index (0=Mon … 6=Sun)
  final Map<int, double> _weekWaterLiters = {};

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _accent = Color(0xFFFF3D00);
  static const _accentSoft = Color(0xFFFF6B00);
  static const _bg1 = Color(0xFF0A0A0A);
  static const _bg2 = Color(0xFF111111);
  static const _bg3 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _textPrimary = Colors.white;
  static const _textSecondary = Color(0xFF888888);
  static const _textTertiary = Color(0xFF555555);

  static const _carbColor = Color(0xFF00A3FF);
  static const _proteinColor = Color(0xFF00E676);
  static const _fatColor = Color(0xFFFFD54F);
  static const _waterColor = Color(0xFF4FC3F7);

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = (DateTime.now().weekday - 1) % 7;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animCurve = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);

    _init();
  }

  Future<void> _init() async {
    await _loadGoals();
    await _snapshotToday();
    await _loadWeek();

    _nutritionSub = NutritionService.instance.stream.listen((data) async {
      if (!mounted) return;
      await CalorieHistoryService.instance.saveTodayFromNutrition(
        calories: data.caloriesEaten,
        calorieGoal: data.calorieGoal,
        carbs: data.carbs,
        carbsGoal: data.carbsGoal,
        protein: data.protein,
        proteinGoal: data.proteinGoal,
        fats: data.fats,
        fatsGoal: data.fatsGoal,
      );
      if (_weekOffset == 0) await _loadWeek();
    });
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final brutlUser = context.read<BrutlUserProvider>().user;
    setState(() {
      _calorieGoal = brutlUser.targetCalories > 0
          ? brutlUser.targetCalories
          : (prefs.getInt('calorie_goal') ?? 2000);
      _carbsGoal = brutlUser.targetCarbs > 0
          ? brutlUser.targetCarbs
          : (prefs.getInt('carbs_goal') ?? 200);
      _proteinGoal = brutlUser.targetProtein > 0
          ? brutlUser.targetProtein
          : (prefs.getInt('protein_goal') ?? 150);
      _fatsGoal = brutlUser.targetFats > 0
          ? brutlUser.targetFats
          : (prefs.getInt('fats_goal') ?? 60);
    });
  }

  Future<void> _snapshotToday() async {
    final nutrition = await NutritionService.instance.loadTodayNutrition();
    await CalorieHistoryService.instance.saveTodayFromNutrition(
      calories: nutrition.caloriesEaten,
      calorieGoal: nutrition.calorieGoal,
      carbs: nutrition.carbs,
      carbsGoal: nutrition.carbsGoal,
      protein: nutrition.protein,
      proteinGoal: nutrition.proteinGoal,
      fats: nutrition.fats,
      fatsGoal: nutrition.fatsGoal,
    );
  }

  Future<void> _loadWaterForWeek() async {
    final waterProvider = context.read<WaterProvider>();
    for (int i = 0; i < 7; i++) {
      final date = _dayAt(i);
      final liters = await waterProvider.getIntakeForDate(date);
      _weekWaterLiters[i] = liters;
    }
  }

  Future<void> _loadWeek() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _barsVisible = false;
    });

    final weekData = await CalorieHistoryService.instance.loadWeek(_weekStart);
    await _loadWaterForWeek();

    if (!mounted) return;
    setState(() {
      _weekData = weekData;
      _isLoading = false;
    });

    _animCtrl.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _barsVisible = true);
    });
  }

  @override
  void dispose() {
    _nutritionSub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  DateTime get _weekStart {
    final now = DateTime.now();
    final daysFromMon = (now.weekday - 1) % 7;
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysFromMon));
    return thisMonday.add(Duration(days: _weekOffset * 7));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  DateTime _dayAt(int index) => _weekStart.add(Duration(days: index));

  String get _weekLabel {
    final fmt = DateFormat('MMM d');
    return '${fmt.format(_weekStart)} – ${fmt.format(_weekEnd)}';
  }

  DailyMacroSnapshot? get _selectedSnapshot {
    final key = CalorieHistoryService.dateKeyFor(_dayAt(_selectedDayIndex));
    return _weekData[key];
  }

  int get _selCalories => _selectedSnapshot?.calories ?? 0;
  int get _selCalGoal => _selectedSnapshot?.calorieGoal ?? _calorieGoal;
  int get _selCarbs => _selectedSnapshot?.carbs ?? 0;
  int get _selCarbsGoal => _selectedSnapshot?.carbsGoal ?? _carbsGoal;
  int get _selProtein => _selectedSnapshot?.protein ?? 0;
  int get _selProteinGoal => _selectedSnapshot?.proteinGoal ?? _proteinGoal;
  int get _selFats => _selectedSnapshot?.fats ?? 0;
  int get _selFatsGoal => _selectedSnapshot?.fatsGoal ?? _fatsGoal;
  double get _selWater => _weekWaterLiters[_selectedDayIndex] ?? 0.0;
  double get _selWaterGoal => context.read<WaterProvider>().goalLiters;

  double get _calProgress =>
      _selCalGoal <= 0 ? 0 : (_selCalories / _selCalGoal).clamp(0.0, 1.0);

  int get _weekAvgCalories {
    final active = _weekData.values.whereType<DailyMacroSnapshot>().toList();
    if (active.isEmpty) return 0;
    return active.map((s) => s.calories).reduce((a, b) => a + b) ~/
        active.length;
  }

  void _changeWeek(int delta) {
    final next = _weekOffset + delta;
    if (next < -3 || next > 0) return;
    setState(() {
      _weekOffset = next;
      _selectedDayIndex = next == 0 ? (DateTime.now().weekday - 1) % 7 : 0;
    });
    _loadWeek();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildWeekNav(),
              const SizedBox(height: 16),
              _buildDayStrip(),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _accent),
                      )
                    : _buildDetailSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final avg = _weekAvgCalories;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textPrimary,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Calories',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 26,
          ),
        ),
        const Spacer(),
        if (avg > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Weekly Avg',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${NumberFormat.decimalPattern().format(avg)} kcal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWeekNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navArrow(
            Icons.chevron_left_rounded,
            () => _changeWeek(-1),
            enabled: _weekOffset > -3,
          ),
          Text(
            _weekLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          _navArrow(
            Icons.chevron_right_rounded,
            () => _changeWeek(1),
            enabled: _weekOffset < 0,
          ),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap, {required bool enabled}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? _bg3 : const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? _textPrimary : _textTertiary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildDayStrip() {
    return Row(
      children: List.generate(7, (i) {
        final day = _dayAt(i);
        final key = CalorieHistoryService.dateKeyFor(day);
        final snap = _weekData[key];
        final isSelected = i == _selectedDayIndex;
        final isToday = _isToday(day);

        final progress = snap != null ? snap.calorieProgress : 0.0;

        // Check if water was logged this day
        final hasWater = (_weekWaterLiters[i] ?? 0) > 0;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedDayIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? _accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? _accent.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _dayNames[i],
                    style: TextStyle(
                      color: isSelected ? _accent : _textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday ? _accent : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day.day.toString(),
                      style: TextStyle(
                        color: isToday
                            ? Colors.white
                            : isSelected
                            ? _textPrimary
                            : _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _MiniRing(
                    progress: progress,
                    size: 24,
                    strokeWidth: 3,
                    color: isSelected ? _accent : _accentSoft,
                  ),
                  // Blue water dot — only shown if water was logged that day
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: hasWater ? 6 : 0,
                    height: hasWater ? 6 : 0,
                    decoration: const BoxDecoration(
                      color: _waterColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Widget _buildDetailSection() {
    final hasData = _selectedSnapshot != null;
    final selectedDate = _dayAt(_selectedDayIndex);
    final formattedDate = DateFormat('EEEE, MMMM d').format(selectedDate);
    final waterGoal = _selWaterGoal;
    final waterProgress = waterGoal > 0
        ? (_selWater / waterGoal).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formattedDate,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animCurve,
                builder: (context, _) {
                  return _BigCalorieRing(
                    progress: _calProgress * _animCurve.value,
                    calories: _selCalories,
                    goal: _selCalGoal,
                  );
                },
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MacroRow(
                      label: 'Calories',
                      value: _selCalories,
                      goal: _selCalGoal,
                      unit: 'kcal',
                      color: _accent,
                    ),
                    const SizedBox(height: 14),
                    _MacroRow(
                      label: 'Carbs',
                      value: _selCarbs,
                      goal: _selCarbsGoal,
                      unit: 'g',
                      color: _carbColor,
                    ),
                    const SizedBox(height: 14),
                    _MacroRow(
                      label: 'Protein',
                      value: _selProtein,
                      goal: _selProteinGoal,
                      unit: 'g',
                      color: _proteinColor,
                    ),
                    const SizedBox(height: 14),
                    _MacroRow(
                      label: 'Fats',
                      value: _selFats,
                      goal: _selFatsGoal,
                      unit: 'g',
                      color: _fatColor,
                    ),
                    const SizedBox(height: 14),
                    // ── Water row (new) ─────────────────────────────────────
                    _WaterMacroRow(
                      currentLiters: _selWater,
                      goalLiters: waterGoal,
                      progress: waterProgress,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!hasData) ...[const SizedBox(height: 24), _buildNoDataChip()],

          const SizedBox(height: 28),
          _buildWeekBarChart(),
        ],
      ),
    );
  }

  Widget _buildNoDataChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _textTertiary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            'No nutrition logged for this day.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBarChart() {
    final maxRaw = _weekData.values
        .whereType<DailyMacroSnapshot>()
        .map((s) => s.calories.toDouble())
        .fold(0.0, (a, b) => b > a ? b : a);
    final goalY = _calorieGoal.toDouble();
    final maxY = (maxRaw > goalY ? maxRaw : goalY) * 1.25;
    final safeMax = maxY <= 0 ? 3000.0 : maxY;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          height: _barsVisible ? 140 : 0,
          child: BarChart(
            BarChartData(
              maxY: safeMax,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions ||
                      response?.spot == null) {
                    return;
                  }
                  setState(
                    () => _selectedDayIndex =
                        response!.spot!.touchedBarGroupIndex,
                  );
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  getTooltipColor: (_) => _bg2,
                  getTooltipItem: (group, tooltipItem, rod, rodIndex) {
                    final snap =
                        _weekData[CalorieHistoryService.dateKeyFor(
                          _dayAt(group.x),
                        )];
                    if (snap == null || snap.calories == 0) return null;
                    return BarTooltipItem(
                      '${snap.calories} kcal',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: goalY,
                    color: _accent.withValues(alpha: 0.5),
                    strokeWidth: 1.2,
                    dashArray: [5, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      labelResolver: (_) {
                        final k = goalY / 1000;
                        final lbl = k % 1 == 0
                            ? '${k.toInt()}k'
                            : '${k.toStringAsFixed(1)}k';
                        return '$lbl goal';
                      },
                    ),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= _dayNames.length) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = idx == _selectedDayIndex;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _dayNames[idx],
                          style: TextStyle(
                            color: isSelected ? _accent : _textSecondary,
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: safeMax / 4,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0xFF1E1E1E), strokeWidth: 0.6),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (i) {
                final key = CalorieHistoryService.dateKeyFor(_dayAt(i));
                final snap = _weekData[key];
                final val = (snap?.calories ?? 0).toDouble();
                final isSelected = i == _selectedDayIndex;

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: val,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      color: isSelected
                          ? _accent
                          : val > 0
                          ? _accentSoft
                          : _accentSoft.withValues(alpha: 0.25),
                    ),
                  ],
                );
              }),
            ),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }
}

// ─── Water Macro Row ──────────────────────────────────────────────────────────

class _WaterMacroRow extends StatelessWidget {
  const _WaterMacroRow({
    required this.currentLiters,
    required this.goalLiters,
    required this.progress,
  });

  final double currentLiters;
  final double goalLiters;
  final double progress;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4FC3F7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Water',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: currentLiters.toStringAsFixed(1),
                    style: const TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${goalLiters.toStringAsFixed(1)} L',
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Extracted Widgets (same as original, kept here for self-contained file) ──

class _MiniRing extends StatelessWidget {
  const _MiniRing({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.color,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          trackColor: const Color(0xFF2A2A2A),
          ringColor: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _BigCalorieRing extends StatelessWidget {
  const _BigCalorieRing({
    required this.progress,
    required this.calories,
    required this.goal,
  });

  final double progress;
  final int calories;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          trackColor: const Color(0xFF2A2A2A),
          ringColor: const Color(0xFFFF3D00),
          ringColorEnd: const Color(0xFFFF6B00),
          strokeWidth: 10,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF3D00),
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                '$calories',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              Text(
                '/ $goal',
                style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
              ),
              const Text(
                'kcal',
                style: TextStyle(color: Color(0xFF555555), fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
    this.ringColorEnd,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color ringColor;
  final Color? ringColorEnd;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (ringColorEnd != null) {
      progressPaint.shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: -1.5708 + 6.2832,
        colors: [ringColor, ringColorEnd!],
        stops: const [0.0, 1.0],
        tileMode: TileMode.clamp,
      ).createShader(rect);
    } else {
      progressPaint.color = ringColor;
    }

    canvas.drawArc(rect, -1.5708, progress * 6.2832, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
  });

  final String label;
  final int value;
  final int goal;
  final String unit;
  final Color color;

  double get _progress => goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$value',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' / $goal $unit',
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: DecoratedBox(decoration: BoxDecoration(color: color)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
