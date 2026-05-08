import 'package:flutter/material.dart';

import '../services/ai_text_meal_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ASK AI DIALOG
// ═══════════════════════════════════════════════════════════════════════════════
//
// Usage:
//   final result = await showAskAiDialog(context);
//   if (result != null) {
//     // result = {'kcal': 450, 'carbs': 60, 'protein': 25, 'fat': 12}
//     _calCtrl.text = result['kcal'].toString();
//     _carbCtrl.text = result['carbs'].toString();
//     _proCtrl.text  = result['protein'].toString();
//     _fatCtrl.text  = result['fat'].toString();
//   }
// ═══════════════════════════════════════════════════════════════════════════════

Future<Map<String, int>?> showAskAiDialog(BuildContext context) {
  return showDialog<Map<String, int>>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AskAiDialog(),
  );
}

class _AskAiDialog extends StatefulWidget {
  const _AskAiDialog();

  @override
  State<_AskAiDialog> createState() => _AskAiDialogState();
}

class _AskAiDialogState extends State<_AskAiDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, int>? _result;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });

    final data = await analyzeTextMeal(query);

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not estimate macros. Please try rephrasing.';
      });
    } else {
      setState(() {
        _isLoading = false;
        _result = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                const Text('🤖', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ask AI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF9A9A9A),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'Describe what you ate — AI will estimate the macros.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666666),
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 16),

            // ── Input ─────────────────────────────────────────────────────
            TextField(
              controller: _controller,
              enabled: !_isLoading,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                hintText: 'e.g. 1 plate biryani, 2 boiled eggs',
                hintStyle: const TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF3D00),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Ask Button ────────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _ask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3D00),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFFFF3D00,
                  ).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Text(
                        'Ask',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            // ── Error ─────────────────────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1010),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Result ────────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 16),
              _MacroResultCard(result: _result!),
              const SizedBox(height: 14),

              // ── Add Button ────────────────────────────────────────────
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_result),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text(
                    'Add to Meal',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Macro Result Card ────────────────────────────────────────────────────────

class _MacroResultCard extends StatelessWidget {
  const _MacroResultCard({required this.result});

  final Map<String, int> result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          // ── Calorie headline ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF3D00),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${result['kcal']} kcal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Macro pills ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MacroPill(
                label: 'Carbs',
                value: result['carbs'] ?? 0,
                color: const Color(0xFF00A3FF),
              ),
              _MacroPill(
                label: 'Protein',
                value: result['protein'] ?? 0,
                color: const Color(0xFF00E676),
              ),
              _MacroPill(
                label: 'Fat',
                value: result['fat'] ?? 0,
                color: const Color(0xFFFFD54F),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '${value}g',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
