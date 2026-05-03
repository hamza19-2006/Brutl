import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_storage_service.dart';

class StepsHistoryScreen extends StatefulWidget {
  const StepsHistoryScreen({super.key});

  @override
  State<StepsHistoryScreen> createState() => _StepsHistoryScreenState();
}

class _StepsHistoryScreenState extends State<StepsHistoryScreen>
    with SingleTickerProviderStateMixin {
  final LocalStorageService _storage = LocalStorageService();

  /// 0 = current week, -1 = last week, -2, -3
  int _weekOffset = 0;

  List<int> _weekData = List.filled(7, 0);
  bool _isReady = false;
  int _stepGoal = 10000;

  late final AnimationController _chartAnim;
  late final Animation<double> _chartCurve;

  @override
  void initState() {
    super.initState();
    _chartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _chartCurve = CurvedAnimation(
      parent: _chartAnim,
      curve: Curves.easeOutCubic,
    );
    _init();
  }

  Future<void> _init() async {
    await _storage.initialize();
    final prefs = await SharedPreferences.getInstance();
    _stepGoal = prefs.getInt('step_goal') ?? 10000;
    _loadWeek();
    if (mounted) setState(() => _isReady = true);
    _chartAnim.forward();
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    super.dispose();
  }

  // Week starts on Monday to match Image 2 (Mon-Sun layout)
  DateTime get _weekStart {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - 1) % 7; // Mon=0 … Sun=6
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysFromMonday));
    return thisMonday.add(Duration(days: _weekOffset * 7));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  String get _weekLabel {
    final fmt = DateFormat('MMM d');
    return '${fmt.format(_weekStart)} \u2013 ${fmt.format(_weekEnd)}';
  }

  void _loadWeek() {
    _weekData = List.generate(7, (i) {
      final date = _weekStart.add(Duration(days: i));
      return _storage.getStepsForKey(LocalStorageService.dateKeyFor(date));
    });
  }

  void _changeWeek(int delta) {
    final next = _weekOffset + delta;
    if (next < -3 || next > 0) return;
    setState(() {
      _weekOffset = next;
      _loadWeek();
    });
    _chartAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final avgSteps = _storage.dailyAverage;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              _buildHeader(avgSteps),
              const SizedBox(height: 28),
              _buildWeekNav(),
              const SizedBox(height: 28),
              Expanded(child: _isReady ? _buildChart() : const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int avgSteps) {
    final formattedAvg = NumberFormat.decimalPattern().format(avgSteps);
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'Steps',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Daily Avg',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF888888),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$formattedAvg steps',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
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
              color: Colors.white,
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
          color: enabled ? const Color(0xFF1A1A1A) : const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : const Color(0xFF333333),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildChart() {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final maxRaw = _weekData
        .fold(0, (prev, v) => v > prev ? v : prev)
        .toDouble();
    final goalY = _stepGoal.toDouble();
    // maxY is at least 20% above the highest value or goal, whichever is bigger
    final rawMax = maxRaw > goalY ? maxRaw : goalY;
    final maxY = rawMax <= 0 ? 20000.0 : rawMax * 1.25;
    final interval = maxY / 5;

    return AnimatedBuilder(
      animation: _chartCurve,
      builder: (context, _) {
        return BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                getTooltipColor: (_) => const Color(0xFF1E1E1E),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final steps = _weekData[group.x];
                  if (steps == 0) return null;
                  final date = _weekStart.add(Duration(days: group.x));
                  final dateStr = DateFormat('MMM d, yyyy').format(date);
                  return BarTooltipItem(
                    '${NumberFormat.decimalPattern().format(steps)} steps\n',
                    const TextStyle(
                      color: Color(0xFFFF3D00),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: dateStr,
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Dashed goal line
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: goalY,
                  color: const Color(0xFFFF3D00).withValues(alpha: 0.55),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 6, bottom: 2),
                    style: const TextStyle(
                      color: Color(0xFFFF3D00),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    labelResolver: (_) {
                      final k = goalY / 1000;
                      final label = k % 1 == 0
                          ? '${k.toInt()}k'
                          : '${k.toStringAsFixed(1)}k';
                      return '$label goal';
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
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    if (value >= meta.max) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '${(value / 1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= dayLabels.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dayLabels[idx],
                        style: const TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: Color(0xFF1E1E1E), strokeWidth: 0.6),
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(7, (i) {
              final raw = _weekData[i].toDouble();
              final animated = raw * _chartCurve.value;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: animated.clamp(0, maxY),
                    width: 26,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    gradient: animated > 0
                        ? const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
                          )
                        : null,
                    color: animated > 0 ? null : const Color(0xFF1A1A1A),
                  ),
                ],
              );
            }),
          ),
          duration: Duration.zero,
        );
      },
    );
  }
}
