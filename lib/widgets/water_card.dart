import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/water_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WATER CARD — compact card shown on home screen below the Steps card.
// Tapping opens WaterBottomSheet.
// ═══════════════════════════════════════════════════════════════════════════════

class WaterCard extends StatelessWidget {
  const WaterCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaterProvider>(
      builder: (context, water, _) {
        final current = water.currentIntakeLiters;
        final goal = water.goalLiters;
        final progress = water.percentage;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const WaterBottomSheet(),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Label + Value in one row ─────────────────────────────
                Row(
                  children: [
                    const Icon(
                      Icons.water_drop_rounded,
                      color: Color(0xFF4FC3F7),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Water',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF888888),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} L',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Slim progress bar ─────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xFF2A2A2A)),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WATER BOTTOM SHEET — quick-add options + custom input
// ═══════════════════════════════════════════════════════════════════════════════

class WaterBottomSheet extends StatefulWidget {
  const WaterBottomSheet({super.key});

  @override
  State<WaterBottomSheet> createState() => _WaterBottomSheetState();
}

class _WaterBottomSheetState extends State<WaterBottomSheet> {
  bool _showCustomInput = false;
  final TextEditingController _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add(double liters) async {
    await context.read<WaterProvider>().addWater(liters);
    if (mounted) Navigator.of(context).pop();
  }

  void _confirmCustom() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid positive number');
      return;
    }
    if (value > 20) {
      setState(() => _error = 'Cannot exceed 20 liters');
      return;
    }
    _add(value);
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
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ────────────────────────────────────────────────────
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
              // ── Title ─────────────────────────────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF4FC3F7),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Log Water',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Consumer<WaterProvider>(
                builder: (context, water, _) => Text(
                  'Today: ${water.currentIntakeLiters.toStringAsFixed(1)}'
                  ' / ${water.goalLiters.toStringAsFixed(1)} L',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (!_showCustomInput) ...[
                // ── Quick-add buttons ─────────────────────────────────────
                _QuickBtn(
                  label: '+ 250 ml',
                  sub: 'Small glass',
                  onTap: () => _add(0.25),
                ),
                const SizedBox(height: 10),
                _QuickBtn(
                  label: '+ 500 ml',
                  sub: 'Standard bottle',
                  onTap: () => _add(0.5),
                ),
                const SizedBox(height: 10),
                _QuickBtn(
                  label: '+ 1000 ml',
                  sub: 'Large bottle',
                  onTap: () => _add(1.0),
                ),
                const SizedBox(height: 10),
                _QuickBtn(
                  label: '+ Other',
                  sub: 'Custom amount',
                  isOther: true,
                  onTap: () => setState(() => _showCustomInput = true),
                ),
              ] else ...[
                // ── Custom input ──────────────────────────────────────────
                Text(
                  'Enter amount (liters)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFAAAAAA),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'e.g. 0.75 or 1.5',
                    hintStyle: const TextStyle(color: Color(0xFF555555)),
                    suffixText: 'L',
                    suffixStyle: const TextStyle(
                      color: Color(0xFF4FC3F7),
                      fontWeight: FontWeight.w600,
                    ),
                    errorText: _error,
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _showCustomInput = false;
                          _ctrl.clear();
                          _error = null;
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF888888),
                          side: const BorderSide(color: Color(0xFF2A2A2A)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _confirmCustom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick-add button tile ────────────────────────────────────────────────────

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({
    required this.label,
    required this.sub,
    required this.onTap,
    this.isOther = false,
  });

  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool isOther;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isOther
                ? const Color(0xFF1A1A1A)
                : const Color(0xFF4FC3F7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOther
                  ? const Color(0xFF2A2A2A)
                  : const Color(0xFF4FC3F7).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOther ? Icons.edit_rounded : Icons.water_drop_rounded,
                color: isOther
                    ? const Color(0xFF888888)
                    : const Color(0xFF4FC3F7),
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isOther ? Colors.white : const Color(0xFF4FC3F7),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isOther
                    ? const Color(0xFF444444)
                    : const Color(0xFF4FC3F7).withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
