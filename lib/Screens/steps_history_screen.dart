import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/local_storage_service.dart';

class StepsHistoryScreen extends StatefulWidget {
  const StepsHistoryScreen({super.key});

  @override
  State<StepsHistoryScreen> createState() => _StepsHistoryScreenState();
}

class _StepsHistoryScreenState extends State<StepsHistoryScreen>
    with SingleTickerProviderStateMixin {
  final LocalStorageService _storage = LocalStorageService();

  /// 0 = current week, -1 = last week, … , -3 = 4 weeks ago
  int _weekOffset = 0;

  List<int> _weekData = List.filled(7, 0);
  bool _isReady = false;

  late final AnimationController _chartAnim;
  late final Animation<double> _chartCurve;

  // ───────────── lifecycle ─────────────

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
    _loadWeek();
    setState(() => _isReady = true);
    _chartAnim.forward();
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    super.dispose();
  }

  // ───────────── week helpers ─────────────

  DateTime get _weekStart {
    final now = DateTime.now();
    // Go to the most recent Sunday
    final currentSunday = now.subtract(Duration(days: now.weekday % 7));
    return DateTime(
      currentSunday.year,
      currentSunday.month,
      currentSunday.day,
    ).add(Duration(days: _weekOffset * 7));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  String get _weekLabel {
    final fmt = DateFormat('MMM d');
    return '${fmt.format(_weekStart)} – ${fmt.format(_weekEnd)}';
  }

  void _loadWeek() {
    _weekData = _storage.getWeekData(_weekStart);
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

  // ───────────── build ─────────────

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
              // ── Header
              _buildHeader(avgSteps),
              const SizedBox(height: 28),

              // ── Week nav
              _buildWeekNav(),
              const SizedBox(height: 28),

              // ── Chart
              Expanded(child: _isReady ? _buildChart() : const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────── header ─────────────

  Widget _buildHeader(int avgSteps) {
    final formattedAvg = NumberFormat.decimalPattern().format(avgSteps);

    return Row(
      children: [
        // Back button
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

  // ───────────── week nav ─────────────

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
          _navArrow(Icons.chevron_left_rounded, () => _changeWeek(-1),
              enabled: _weekOffset > -3),
          Text(
            _weekLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
          _navArrow(Icons.chevron_right_rounded, () => _changeWeek(1),
              enabled: _weekOffset < 0),
        ],
      ),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap,
      {required bool enabled}) {
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

  // ───────────── bar chart ─────────────

  Widget _buildChart() {
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const maxY = 18000.0;
    const interval = 3600.0;

    return AnimatedBuilder(
      animation: _chartCurve,
      builder: (context, _) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final steps = _weekData[group.x];
                      if (steps == 0) return null;
                      return BarTooltipItem(
                        NumberFormat.decimalPattern().format(steps),
                        Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: const Color(0xFFFF3D00),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                      );
                    },
                  ),
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
                        if (value == maxY) {
                          return const SizedBox.shrink();
                        }
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
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFF333333),
                      strokeWidth: 0.6,
                    );
                  },
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
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: animated > 0
                            ? const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color(0xFFFF3D00),
                                  Color(0xFFFF6B00),
                                ],
                              )
                            : null,
                        color: animated > 0 ? null : const Color(0xFF1A1A1A),
                      ),
                    ],
                  );
                }),
              ),
              duration: Duration.zero, // we handle animation ourselves
            ),
          ),
        );
      },
    );
  }
}
