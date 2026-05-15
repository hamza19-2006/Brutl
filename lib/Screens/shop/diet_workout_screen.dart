import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/brutl_user_provider.dart';

class DietWorkoutScreen extends StatefulWidget {
  const DietWorkoutScreen({super.key});

  @override
  State<DietWorkoutScreen> createState() => _DietWorkoutScreenState();
}

class _DietWorkoutScreenState extends State<DietWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _otherGoalController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _stepsController = TextEditingController();
  final _budgetController = TextEditingController();
  final _mealsController = TextEditingController();
  final _kcalController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _suggestionsController = TextEditingController();

  String _goal = 'Body Recomp';
  int _workoutDays = 4;
  String _currency = 'PKR';
  String _duration = '7 Days';
  bool _isGenerating = false;
  bool _showDownload = false;
  bool _isHydrated = false;
  String? _generatedFilePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isHydrated) return;
    final user = context.read<BrutlUserProvider>().user;
    _weightController.text = user.weight > 0
        ? user.weight.toStringAsFixed(1)
        : '';
    _heightController.text = user.height > 0
        ? user.height.toStringAsFixed(1)
        : '';
    _bodyFatController.text = user.bodyFatAverage > 0
        ? user.bodyFatAverage.toStringAsFixed(1)
        : '';
    _stepsController.text = user.dailySteps > 0
        ? user.dailySteps.toString()
        : '';
    _kcalController.text = user.targetCalories.toString();
    _carbsController.text = user.targetCarbs.toString();
    _proteinController.text = user.targetProtein.toString();
    _fatController.text = user.targetFats.toString();
    _isHydrated = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _otherGoalController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    _stepsController.dispose();
    _budgetController.dispose();
    _mealsController.dispose();
    _kcalController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  Future<void> _simulateGenerate() async {
    setState(() {
      _isGenerating = true;
      _showDownload = false;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _showDownload = true;
    });
  }

  Future<void> _generateAndSavePdf() async {
    final user = context.read<BrutlUserProvider>().user;
    final doc = pw.Document();
    final userName = user.displayName.isNotEmpty
        ? user.displayName
        : user.username;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Brutl App',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Name: $userName'),
          pw.Text('Weight: ${_weightController.text}'),
          pw.Text('Height: ${_heightController.text}'),
          pw.Text('Body Fat: ${_bodyFatController.text}%'),
          pw.Text('Kcal: ${_kcalController.text}'),
          pw.Text(
            'Goal: ${_goal == 'Other' ? _otherGoalController.text.trim() : _goal}',
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Mock Diet Plan',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: const ['Meal', 'Time', 'Food', 'Kcal'],
            data: const [
              ['Meal 1', '08:00', 'Oats + Eggs', '450'],
              ['Meal 2', '12:30', 'Chicken + Rice', '620'],
              ['Meal 3', '16:30', 'Yogurt + Nuts', '300'],
              ['Meal 4', '20:00', 'Fish + Potatoes', '550'],
            ],
          ),
        ],
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/diet_plan.pdf');
    await file.writeAsBytes(await doc.save());
    _generatedFilePath = file.path;

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved PDF to ${file.path}')));
  }

  Future<void> _openPdf() async {
    if (_generatedFilePath == null) {
      await _generateAndSavePdf();
    }
    final path = _generatedFilePath;
    if (path == null) return;
    final uri = Uri.file(path);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open PDF file.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet & Workout Plan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Diet Plan'),
            Tab(text: 'Workout Plan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDietPlanForm(),
          const Center(child: Text('Workout Plan (Coming Soon)')),
        ],
      ),
    );
  }

  Widget _buildDietPlanForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _goal,
            decoration: const InputDecoration(labelText: 'Goal'),
            items: const ['Body Recomp', 'Weight Loss', 'Weight Gain', 'Other']
                .map((goal) => DropdownMenuItem(value: goal, child: Text(goal)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _goal = value);
            },
          ),
          if (_goal == 'Other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otherGoalController,
              decoration: const InputDecoration(labelText: 'Custom Goal'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'User Stats',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Height'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyFatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Body Fat %'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _stepsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Steps Goal'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: _workoutDays,
            decoration: const InputDecoration(labelText: 'Workout Days'),
            items: List<int>.generate(7, (index) => index + 1)
                .map((day) => DropdownMenuItem(value: day, child: Text('$day')))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _workoutDays = value);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Budget'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: const ['PKR', 'USD', 'EUR', 'GBP']
                      .map(
                        (currency) => DropdownMenuItem(
                          value: currency,
                          child: Text(currency),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _currency = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mealsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Meals Per Day'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Macros',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _kcalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kcal'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _carbsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Carbs'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _proteinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Protein'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Fat'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _duration,
            decoration: const InputDecoration(labelText: 'Plan Duration'),
            items: const ['7 Days', '30 Days']
                .map(
                  (duration) =>
                      DropdownMenuItem(value: duration, child: Text(duration)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _duration = value);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _suggestionsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Suggestions / Notes / Allergies',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isGenerating ? null : _simulateGenerate,
            child: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate with AI'),
          ),
          if (_showDownload) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _openPdf,
              child: const Text('Download PDF'),
            ),
          ],
        ],
      ),
    );
  }
}
