import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_extensions.dart';
import '../../providers/brutl_user_provider.dart';

class DietWorkoutScreen extends StatefulWidget {
  const DietWorkoutScreen({super.key});

  @override
  State<DietWorkoutScreen> createState() => _DietWorkoutScreenState();
}

class _DietWorkoutScreenState extends State<DietWorkoutScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _goalOptions = <String>[
    'Body Recomp',
    'Weight Loss',
    'Weight Gain',
    'Other',
  ];
  static const List<String> _experienceOptions = <String>[
    'Beginner',
    'Intermediate',
    'Advanced',
  ];
  static const List<String> _equipmentOptions = <String>[
    'Full Gym',
    'Home Gym (Dumbbells only)',
    'Bodyweight',
  ];
  static const List<String> _splitOptions = <String>[
    'Push Pull Legs',
    'Bro Split',
    'Push Pull Leg Upper Lower',
    'Upper Lower',
    'Custom',
  ];
  static const Map<String, List<String>> _splitDayPresets = <String, List<String>>{
    'Push Pull Legs': <String>['Chest & Triceps', 'Back & Biceps', 'Leg & Shoulders', 'Chest & Triceps', 'Back & Biceps', 'Leg & Shoulders', 'Rest Day'],
    'Bro Split': <String>['Chest', 'Back', 'Arms', 'Shoulder', 'Legs', 'Rest Day', 'Rest Day'],
    'Push Pull Leg Upper Lower': <String>['Chest & Triceps', 'Back & Biceps', 'Leg & Shoulders', 'Rest Day', 'Upper Day', 'Lower Day', 'Rest Day'],
    'Upper Lower': <String>['Upper A', 'Lower A', 'Rest Day', 'Upper B', 'Lower B', 'Rest Day', 'Rest Day'],
  };

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
  final _workoutSplitNameController = TextEditingController();
  final _workoutCustomGoalController = TextEditingController();
  final _workoutAgeController = TextEditingController();
  final _workoutSuggestionsController = TextEditingController();
  final List<TextEditingController> _dayNameControllers =
      <TextEditingController>[];

  String _goal = 'Body Recomp';
  int _workoutDays = 4;
  String _currency = 'PKR';
  String _duration = '7 Days';
  bool _isGenerating = false;
  bool _showDownload = false;
  bool _isHydrated = false;
  String _workoutGoal = 'Body Recomp';
  int _workoutDaysPerWeek = 7;
  String _experienceLevel = 'Beginner';
  String _equipmentAccess = 'Full Gym';
  bool _isWorkoutGenerating = false;
  bool _showWorkoutDownload = false;
  String _selectedWorkoutSplit = 'Push Pull Legs';

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
    _workoutAgeController.text = user.age > 0 ? user.age.toString() : '';

    final savedTemplate = user.workoutSplitTemplate.trim();
    _selectedWorkoutSplit = _resolveSplitOption(savedTemplate);
    _workoutSplitNameController.text = _selectedWorkoutSplit == 'Custom' && savedTemplate.isNotEmpty
        ? savedTemplate
        : _selectedWorkoutSplit;

    if (_goalOptions.contains(user.bodyGoal)) {
      _workoutGoal = user.bodyGoal;
    } else if (user.bodyGoal.trim().isNotEmpty) {
      _workoutGoal = 'Other';
      _workoutCustomGoalController.text = user.bodyGoal;
    }

    // Also hydrate the Diet tab's goal and custom goal field if the user
    // has a saved custom body goal. This ensures the Diet "Other" field is
    // pre-filled and visible when appropriate.
    if (_goalOptions.contains(user.bodyGoal)) {
      _goal = user.bodyGoal;
    } else if (user.bodyGoal.trim().isNotEmpty) {
      _goal = 'Other';
      _otherGoalController.text = user.bodyGoal;
    }

    if (_selectedWorkoutSplit == 'Custom') {
      final initialDayNames = user.customSplitDays.isNotEmpty
          ? user.customSplitDays
          : List<String>.generate(
              _workoutDaysPerWeek,
              (int index) => 'Day ${index + 1}',
            );
      _workoutDaysPerWeek = initialDayNames.length.clamp(1, 7);
      _syncWorkoutDayControllers(
        _workoutDaysPerWeek,
        seededValues: initialDayNames,
      );
    } else {
      _workoutDaysPerWeek = 7;
      _syncWorkoutDayControllers(
        7,
        seededValues: _splitDayPresets[_selectedWorkoutSplit]!,
      );
    }
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
    _workoutSplitNameController.dispose();
    _workoutCustomGoalController.dispose();
    _workoutAgeController.dispose();
    _workoutSuggestionsController.dispose();
    for (final controller in _dayNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncWorkoutDayControllers(
    int targetCount, {
    List<String>? seededValues,
    bool forceSeed = false,
  }) {
    final preservedValues = _dayNameControllers
        .map((TextEditingController controller) => controller.text)
        .toList();
    final nextValues = List<String>.generate(targetCount, (int index) {
      if (seededValues != null && index < seededValues.length) {
        if (forceSeed) return seededValues[index];
        if (seededValues[index].trim().isNotEmpty) {
          return seededValues[index].trim();
        }
      }
      if (index < preservedValues.length &&
          preservedValues[index].trim().isNotEmpty) {
        return preservedValues[index].trim();
      }
      return 'Day ${index + 1}';
    });

    while (_dayNameControllers.length > targetCount) {
      _dayNameControllers.removeLast().dispose();
    }
    while (_dayNameControllers.length < targetCount) {
      _dayNameControllers.add(TextEditingController());
    }

    for (var index = 0; index < targetCount; index++) {
      if (_dayNameControllers[index].text != nextValues[index]) {
        _dayNameControllers[index].text = nextValues[index];
      }
    }
  }

  String _resolveSplitOption(String template) {
    if (_splitOptions.contains(template)) return template;
    final lower = template.toLowerCase();
    if (lower.contains('push pull leg upper lower')) {
      return 'Push Pull Leg Upper Lower';
    }
    if (lower.contains('push pull leg') || lower.contains('ppl')) {
      return 'Push Pull Legs';
    }
    if (lower.contains('bro')) return 'Bro Split';
    if (lower.contains('upper lower')) return 'Upper Lower';
    return 'Custom';
  }

  void _onWorkoutSplitChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedWorkoutSplit = value;
      _workoutSplitNameController.text = value;
      _showWorkoutDownload = false;

      if (value == 'Custom') {
        _syncWorkoutDayControllers(
          _workoutDaysPerWeek,
          seededValues: List<String>.generate(_workoutDaysPerWeek, (_) => ''),
          forceSeed: true,
        );
      } else {
        _workoutDaysPerWeek = 7;
        _syncWorkoutDayControllers(
          7,
          seededValues: _splitDayPresets[value]!,
        );
      }
    });
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

  Future<void> _simulateWorkoutGeneration() async {
    setState(() {
      _isWorkoutGenerating = true;
      _showWorkoutDownload = false;
    });
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() {
      _isWorkoutGenerating = false;
      _showWorkoutDownload = true;
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
        build: (pw.Context context) => <pw.Widget>[
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
            headers: const <String>['Meal', 'Time', 'Food', 'Kcal'],
            data: const <List<String>>[
              <String>['Meal 1', '08:00', 'Oats + Eggs', '450'],
              <String>['Meal 2', '12:30', 'Chicken + Rice', '620'],
              <String>['Meal 3', '16:30', 'Yogurt + Nuts', '300'],
              <String>['Meal 4', '20:00', 'Fish + Potatoes', '550'],
            ],
          ),
        ],
      ),
    );

    final directory = await _resolveWorkoutDownloadDirectory();
    final safeTimestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/diet_plan_$safeTimestamp.pdf');
    await file.writeAsBytes(await doc.save());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Diet Plan saved to Downloads')),
      );
  }

  Future<Directory> _resolveWorkoutDownloadDirectory() async {
    if (Platform.isAndroid) {
      const androidDownloads = '/storage/emulated/0/Download';
      final downloadsDirectory = Directory(androidDownloads);
      if (await downloadsDirectory.exists()) {
        return downloadsDirectory;
      }
    }

    final directory = await getDownloadsDirectory();
    if (directory != null) {
      return directory;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _generateWorkoutPdf() async {
    final user = context.read<BrutlUserProvider>().user;
    final workoutGoal = _workoutGoal == 'Other'
        ? _workoutCustomGoalController.text.trim()
        : _workoutGoal;
    final athleteName = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : (user.username.trim().isNotEmpty
              ? user.username.trim()
              : 'Brutl Athlete');
    final dayNames = List<String>.generate(_dayNameControllers.length, (
      int index,
    ) {
      final value = _dayNameControllers[index].text.trim();
      return value.isNotEmpty ? value : 'Day ${index + 1}';
    });
    final plan = _buildWorkoutPlan(
      dayNames: dayNames,
      compoundRepRange: '${user.compoundRepMin}-${user.compoundRepMax} reps',
      isolationRepRange: '${user.isolationRepMin}-${user.isolationRepMax} reps',
      equipmentAccess: _equipmentAccess,
    );

    final document = pw.Document();
    final summaryItems = <_PdfSummaryItem>[
      _PdfSummaryItem(
        'Goal',
        workoutGoal.isNotEmpty ? workoutGoal : 'Body Recomp',
      ),
      _PdfSummaryItem(
        'Weight',
        _weightController.text.trim().isNotEmpty
            ? '${_weightController.text.trim()} kg'
            : '--',
      ),
      _PdfSummaryItem(
        'Height',
        _heightController.text.trim().isNotEmpty
            ? '${_heightController.text.trim()} cm'
            : '--',
      ),
      _PdfSummaryItem('Experience', _experienceLevel),
      _PdfSummaryItem('Workout Days', '${_workoutDaysPerWeek} / week'),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 42),
        footer: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: <pw.Widget>[
              pw.Text(
                'Generated by Brutl AI',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'brutl.app | @brutlfitness',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F5F5),
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE6E6E6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'BRUTL FITNESS',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF111111),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Custom Plan for: $athleteName',
                  style: const pw.TextStyle(
                    fontSize: 13,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Split: ${_workoutSplitNameController.text.trim().isNotEmpty ? _workoutSplitNameController.text.trim() : 'Custom Workout Split'}',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: summaryItems
                .map(
                  (_PdfSummaryItem item) => pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFFF7ED),
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFFFD6BF),
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        pw.Text(
                          item.label,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          item.value,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          ...plan.expand(((_WorkoutDayPlan dayPlan) sync* {
            yield pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF111111),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                dayPlan.name,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            yield pw.TableHelper.fromTextArray(
              headers: const <String>[
                'Exercise',
                'Sets',
                'Reps',
                'Rest Period',
              ],
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFFFF1EA),
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF111111),
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(8),
              data: dayPlan.exercises
                  .map(
                    (_WorkoutExercise exercise) => <String>[
                      exercise.name,
                      exercise.sets,
                      exercise.reps,
                      exercise.restPeriod,
                    ],
                  )
                  .toList(),
            );
            yield pw.SizedBox(height: 14);
          })),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  "Coach's Notes",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  _workoutSuggestionsController.text.trim().isNotEmpty
                      ? _workoutSuggestionsController.text.trim()
                      : 'Progressive overload, clean form, and recovery remain the top priorities for this cycle.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final directory = await _resolveWorkoutDownloadDirectory();
    final safeTimestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/workout_plan_$safeTimestamp.pdf');
    await file.writeAsBytes(await document.save());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Workout Plan saved to Downloads')),
      );
  }

  List<_WorkoutDayPlan> _buildWorkoutPlan({
    required List<String> dayNames,
    required String compoundRepRange,
    required String isolationRepRange,
    required String equipmentAccess,
  }) {
    return dayNames.map((_normalizeWorkoutDayName)).map((
      _WorkoutDayDescriptor descriptor,
    ) {
      final exercises = _exerciseLibraryForDay(
        descriptor: descriptor,
        compoundRepRange: compoundRepRange,
        isolationRepRange: isolationRepRange,
        equipmentAccess: equipmentAccess,
      );
      return _WorkoutDayPlan(
        name: descriptor.displayName,
        exercises: exercises,
      );
    }).toList();
  }

  _WorkoutDayDescriptor _normalizeWorkoutDayName(String rawName) {
    final trimmedName = rawName.trim();
    final lowerName = trimmedName.toLowerCase();

    if (lowerName.contains('push') || lowerName.contains('chest')) {
      return _WorkoutDayDescriptor(displayName: trimmedName, template: 'push');
    }
    if (lowerName.contains('pull') || lowerName.contains('back')) {
      return _WorkoutDayDescriptor(displayName: trimmedName, template: 'pull');
    }
    if (lowerName.contains('leg') || lowerName.contains('lower')) {
      return _WorkoutDayDescriptor(displayName: trimmedName, template: 'legs');
    }
    if (lowerName.contains('upper')) {
      return _WorkoutDayDescriptor(displayName: trimmedName, template: 'upper');
    }
    if (lowerName.contains('arm')) {
      return _WorkoutDayDescriptor(displayName: trimmedName, template: 'arms');
    }
    if (lowerName.contains('core') || lowerName.contains('abs')) {
      return _WorkoutDayDescriptor(displayName: trimmedName, template: 'core');
    }
    if (lowerName.contains('cardio') || lowerName.contains('conditioning')) {
      return _WorkoutDayDescriptor(
        displayName: trimmedName,
        template: 'cardio',
      );
    }

    return _WorkoutDayDescriptor(
      displayName: trimmedName,
      template: trimmedName.toLowerCase().contains('full')
          ? 'full_body'
          : 'upper',
    );
  }

  List<_WorkoutExercise> _exerciseLibraryForDay({
    required _WorkoutDayDescriptor descriptor,
    required String compoundRepRange,
    required String isolationRepRange,
    required String equipmentAccess,
  }) {
    final isBodyweight = equipmentAccess == 'Bodyweight';
    final isDumbbellOnly = equipmentAccess == 'Home Gym (Dumbbells only)';

    switch (descriptor.template) {
      case 'push':
        if (isBodyweight) {
          return <_WorkoutExercise>[
            _WorkoutExercise('Tempo Push-Up', '4', compoundRepRange, '75 sec'),
            _WorkoutExercise(
              'Decline Push-Up',
              '3',
              isolationRepRange,
              '60 sec',
            ),
            _WorkoutExercise('Pike Push-Up', '3', isolationRepRange, '60 sec'),
            _WorkoutExercise('Bench Dip', '3', isolationRepRange, '45 sec'),
          ];
        }
        if (isDumbbellOnly) {
          return <_WorkoutExercise>[
            _WorkoutExercise(
              'Dumbbell Flat Press',
              '4',
              compoundRepRange,
              '90 sec',
            ),
            _WorkoutExercise(
              'Seated Dumbbell Shoulder Press',
              '3',
              compoundRepRange,
              '75 sec',
            ),
            _WorkoutExercise(
              'Incline Dumbbell Fly',
              '3',
              isolationRepRange,
              '60 sec',
            ),
            _WorkoutExercise(
              'Dumbbell Lateral Raise',
              '3',
              isolationRepRange,
              '45 sec',
            ),
          ];
        }
        return <_WorkoutExercise>[
          _WorkoutExercise(
            'Barbell Bench Press',
            '4',
            compoundRepRange,
            '120 sec',
          ),
          _WorkoutExercise(
            'Incline Dumbbell Press',
            '3',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise(
            'Machine Chest Fly',
            '3',
            isolationRepRange,
            '60 sec',
          ),
          _WorkoutExercise(
            'Cable Lateral Raise',
            '3',
            isolationRepRange,
            '45 sec',
          ),
        ];
      case 'pull':
        if (isBodyweight) {
          return <_WorkoutExercise>[
            _WorkoutExercise(
              'Pull-Up / Assisted Pull-Up',
              '4',
              compoundRepRange,
              '90 sec',
            ),
            _WorkoutExercise('Inverted Row', '3', compoundRepRange, '75 sec'),
            _WorkoutExercise('Prone Y Raise', '3', isolationRepRange, '45 sec'),
            _WorkoutExercise('Towel Curl Iso Hold', '3', '30 sec', '30 sec'),
          ];
        }
        if (isDumbbellOnly) {
          return <_WorkoutExercise>[
            _WorkoutExercise(
              'One-Arm Dumbbell Row',
              '4',
              compoundRepRange,
              '90 sec',
            ),
            _WorkoutExercise(
              'Chest-Supported Row',
              '3',
              compoundRepRange,
              '75 sec',
            ),
            _WorkoutExercise('Rear Delt Fly', '3', isolationRepRange, '45 sec'),
            _WorkoutExercise('Hammer Curl', '3', isolationRepRange, '45 sec'),
          ];
        }
        return <_WorkoutExercise>[
          _WorkoutExercise(
            'Weighted Pull-Up',
            '4',
            compoundRepRange,
            '120 sec',
          ),
          _WorkoutExercise(
            'Chest-Supported Row',
            '3',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise('Lat Pulldown', '3', isolationRepRange, '60 sec'),
          _WorkoutExercise('Cable Curl', '3', isolationRepRange, '45 sec'),
        ];
      case 'legs':
        if (isBodyweight) {
          return <_WorkoutExercise>[
            _WorkoutExercise('Tempo Squat', '4', compoundRepRange, '75 sec'),
            _WorkoutExercise('Reverse Lunge', '3', isolationRepRange, '60 sec'),
            _WorkoutExercise(
              'Single-Leg Hip Bridge',
              '3',
              isolationRepRange,
              '45 sec',
            ),
            _WorkoutExercise(
              'Standing Calf Raise',
              '4',
              '15-20 reps',
              '30 sec',
            ),
          ];
        }
        if (isDumbbellOnly) {
          return <_WorkoutExercise>[
            _WorkoutExercise('Goblet Squat', '4', compoundRepRange, '90 sec'),
            _WorkoutExercise(
              'Dumbbell Romanian Deadlift',
              '3',
              compoundRepRange,
              '75 sec',
            ),
            _WorkoutExercise(
              'Bulgarian Split Squat',
              '3',
              isolationRepRange,
              '60 sec',
            ),
            _WorkoutExercise(
              'Dumbbell Calf Raise',
              '4',
              '15-20 reps',
              '30 sec',
            ),
          ];
        }
        return <_WorkoutExercise>[
          _WorkoutExercise('Back Squat', '4', compoundRepRange, '120 sec'),
          _WorkoutExercise(
            'Romanian Deadlift',
            '3',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise('Leg Press', '3', isolationRepRange, '75 sec'),
          _WorkoutExercise('Seated Leg Curl', '3', isolationRepRange, '60 sec'),
        ];
      case 'arms':
        return <_WorkoutExercise>[
          _WorkoutExercise(
            isBodyweight ? 'Diamond Push-Up' : 'Close-Grip Press',
            '4',
            compoundRepRange,
            '75 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Chair Dip' : 'Overhead Tricep Extension',
            '3',
            isolationRepRange,
            '45 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Towel Curl' : 'Alternating Curl',
            '3',
            isolationRepRange,
            '45 sec',
          ),
          _WorkoutExercise('Forearm Finisher', '2', '45-60 sec', '30 sec'),
        ];
      case 'core':
        return <_WorkoutExercise>[
          _WorkoutExercise('Hollow Body Hold', '3', '30-40 sec', '30 sec'),
          _WorkoutExercise('Weighted Crunch', '3', '12-15 reps', '30 sec'),
          _WorkoutExercise('Dead Bug', '3', '10-12 / side', '30 sec'),
          _WorkoutExercise('Side Plank', '3', '30 sec / side', '20 sec'),
        ];
      case 'cardio':
        return <_WorkoutExercise>[
          _WorkoutExercise(
            'Bike / Run Intervals',
            '5',
            '60 sec hard',
            '60 sec',
          ),
          _WorkoutExercise('Incline Walk', '1', '15 min', '---'),
          _WorkoutExercise(
            'Battle Rope / Shadow Boxing',
            '4',
            '30 sec',
            '30 sec',
          ),
          _WorkoutExercise('Mobility Cooldown', '1', '8 min', '---'),
        ];
      case 'full_body':
        return <_WorkoutExercise>[
          _WorkoutExercise(
            isBodyweight ? 'Push-Up' : 'Front Squat',
            '4',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Bodyweight Row' : 'Romanian Deadlift',
            '3',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Walking Lunge' : 'Dumbbell Bench Press',
            '3',
            isolationRepRange,
            '60 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Plank Reach' : 'Cable Row',
            '3',
            isolationRepRange,
            '60 sec',
          ),
        ];
      case 'upper':
      default:
        return <_WorkoutExercise>[
          _WorkoutExercise(
            isBodyweight ? 'Push-Up' : 'Incline Press',
            '4',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Inverted Row' : 'Barbell Row',
            '4',
            compoundRepRange,
            '90 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Pike Push-Up' : 'Machine Shoulder Press',
            '3',
            isolationRepRange,
            '60 sec',
          ),
          _WorkoutExercise(
            isBodyweight ? 'Band Pull-Apart' : 'Cable Face Pull',
            '3',
            isolationRepRange,
            '45 sec',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<BrutlUserProvider>().user;
    final displayName = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : (user.username.trim().isNotEmpty
              ? user.username.trim()
              : 'Brutl Athlete');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet & Workout Plan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Diet Plan'),
            Tab(text: 'Workout Plan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildDietPlanForm(),
          _buildWorkoutPlanForm(displayName),
        ],
      ),
    );
  }

  Widget _buildAIBanner({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderAccent),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.accentGlow,
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.accentPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietPlanForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildAIBanner(
            title: 'Build Your AI-Powered Diet Plan',
            subtitle:
                'Let Brutl AI craft the perfect nutrition strategy based on your macros and body metrics.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _goal,
            decoration: const InputDecoration(labelText: 'Goal'),
            items:
                const <String>[
                      'Body Recomp',
                      'Weight Loss',
                      'Weight Gain',
                      'Other',
                    ]
                    .map(
                      (String goal) => DropdownMenuItem<String>(
                        value: goal,
                        child: Text(goal),
                      ),
                    )
                    .toList(),
            onChanged: (String? value) {
              if (value == null) return;
              setState(() => _goal = value);
            },
          ),
          if (_goal == 'Other') ...<Widget>[
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
            decoration: const InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg / lbs',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Height',
              suffixText: 'cm',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyFatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Body Fat %',
              suffixText: '%',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _stepsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Steps Goal',
              suffixText: 'steps',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Workout Days per Week',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: _workoutDays,
            decoration: const InputDecoration(
              hintText: 'Select workout days',
              border: OutlineInputBorder(),
            ),
            items: List<int>.generate(7, (int index) => index + 1)
                .map(
                  (int day) =>
                      DropdownMenuItem<int>(value: day, child: Text('$day')),
                )
                .toList(),
            onChanged: (int? value) {
              if (value == null) return;
              setState(() => _workoutDays = value);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
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
                  items: const <String>['PKR', 'USD', 'EUR', 'GBP']
                      .map(
                        (String currency) => DropdownMenuItem<String>(
                          value: currency,
                          child: Text(currency),
                        ),
                      )
                      .toList(),
                  onChanged: (String? value) {
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
            decoration: const InputDecoration(
              labelText: 'Kcal',
              suffixText: 'kcal',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _carbsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Carbs',
              suffixText: 'g Carbs',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _proteinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Protein',
              suffixText: 'g Protein',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fat',
              suffixText: 'g Fat',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Diet Plan Duration',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _duration,
            decoration: const InputDecoration(
              hintText: 'Select plan duration',
              border: OutlineInputBorder(),
            ),
            items: const <String>['7 Days', '30 Days']
                .map(
                  (String duration) => DropdownMenuItem<String>(
                    value: duration,
                    child: Text(duration),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
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
          ElevatedButton.icon(
            onPressed: _isGenerating ? null : _simulateGenerate,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _isGenerating ? 'Analyzing Stats...' : 'Generate with AI',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (_showDownload) ...<Widget>[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _generateAndSavePdf,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusSuccess,
                foregroundColor: AppColors.backgroundPrimary,
                shadowColor: AppColors.statusSuccess.withOpacity(0.4),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutPlanForm(String displayName) {
    final spacing = context.brutl.spacing;
    final colors = context.brutl.colors;

    return Container(
      color: colors.bg1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildAIBanner(
              title: 'Build Your AI-Powered Workout Plan',
              subtitle:
                  'Generate a custom training split optimized for your specific goals and equipment.',
            ),
            SizedBox(height: spacing.lg),
            _buildWorkoutSection(
              title: 'Split Setup',
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: _selectedWorkoutSplit,
                    decoration: const InputDecoration(
                      labelText: 'Workout Split',
                    ),
                    items: _splitOptions
                        .map(
                          (String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) => _onWorkoutSplitChanged(value),
                  ),
                  if (_selectedWorkoutSplit == 'Custom') ...<Widget>[
                    SizedBox(height: spacing.md),
                    DropdownButtonFormField<int>(
                      value: _workoutDaysPerWeek,
                      decoration: const InputDecoration(
                        labelText: 'Days per Week',
                      ),
                      items: List<int>.generate(7, (int index) => index + 1)
                          .map(
                            (int day) => DropdownMenuItem<int>(
                              value: day,
                              child: Text('$day'),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) {
                        if (value == null) return;
                        setState(() {
                          _workoutDaysPerWeek = value;
                          _syncWorkoutDayControllers(
                            value,
                            seededValues: List<String>.generate(value, (_) => ''),
                            forceSeed: true,
                          );
                          _showWorkoutDownload = false;
                        });
                      },
                    ),
                  ],
                  SizedBox(height: spacing.md),
                  ...List<Widget>.generate(_dayNameControllers.length, (
                    int index,
                  ) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _dayNameControllers.length - 1
                            ? 0
                            : spacing.md,
                      ),
                      child: TextField(
                        controller: _dayNameControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Day ${index + 1} Name',
                          prefixIcon: const Icon(Icons.edit_calendar_outlined),
                        ),
                        onChanged: (_) {
                          if (_showWorkoutDownload) {
                            setState(() => _showWorkoutDownload = false);
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
            _buildWorkoutSection(
              title: 'Goal & Training Preferences',
              child: Column(
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    value: _workoutGoal,
                    decoration: const InputDecoration(
                      labelText: 'Fitness Goal',
                    ),
                    items: _goalOptions
                        .map(
                          (String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() {
                        _workoutGoal = value;
                        _showWorkoutDownload = false;
                      });
                    },
                  ),
                  if (_workoutGoal == 'Other') ...<Widget>[
                    SizedBox(height: spacing.md),
                    TextField(
                      controller: _workoutCustomGoalController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Goal',
                      ),
                      onChanged: (_) {
                        if (_showWorkoutDownload) {
                          setState(() => _showWorkoutDownload = false);
                        }
                      },
                    ),
                  ],
                  SizedBox(height: spacing.md),
                  DropdownButtonFormField<String>(
                    value: _experienceLevel,
                    decoration: const InputDecoration(
                      labelText: 'Experience Level',
                    ),
                    items: _experienceOptions
                        .map(
                          (String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() {
                        _experienceLevel = value;
                        _showWorkoutDownload = false;
                      });
                    },
                  ),
                  SizedBox(height: spacing.md),
                  DropdownButtonFormField<String>(
                    value: _equipmentAccess,
                    decoration: const InputDecoration(
                      labelText: 'Equipment Access',
                    ),
                    items: _equipmentOptions
                        .map(
                          (String option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setState(() {
                        _equipmentAccess = value;
                        _showWorkoutDownload = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
            _buildWorkoutSection(
              title: 'User Stats',
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg / lbs',
                    ),
                    onChanged: (_) {
                      if (_showWorkoutDownload) {
                        setState(() => _showWorkoutDownload = false);
                      }
                    },
                  ),
                  SizedBox(height: spacing.md),
                  TextField(
                    controller: _heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                    onChanged: (_) {
                      if (_showWorkoutDownload) {
                        setState(() => _showWorkoutDownload = false);
                      }
                    },
                  ),
                  SizedBox(height: spacing.md),
                  TextField(
                    controller: _workoutAgeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      suffixText: 'years',
                    ),
                    onChanged: (_) {
                      if (_showWorkoutDownload) {
                        setState(() => _showWorkoutDownload = false);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
            _buildWorkoutSection(
              title: 'Suggestions / Injuries',
              child: TextField(
                controller: _workoutSuggestionsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Suggestions / Injuries',
                  alignLabelWithHint: true,
                  hintText:
                      'Add injury notes, preferred movements, or coaching cues.',
                ),
                onChanged: (_) {
                  if (_showWorkoutDownload) {
                    setState(() => _showWorkoutDownload = false);
                  }
                },
              ),
            ),
            SizedBox(height: spacing.xl),
            ElevatedButton(
              onPressed: _isWorkoutGenerating
                  ? null
                  : _simulateWorkoutGeneration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_isWorkoutGenerating) ...<Widget>[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: spacing.md),
                  ] else ...<Widget>[
                    const Icon(Icons.auto_awesome_rounded),
                    SizedBox(width: spacing.sm),
                  ],
                  Text(
                    _isWorkoutGenerating
                        ? 'Analyzing Stats...'
                        : 'Generate with AI',
                  ),
                ],
              ),
            ),
            if (_showWorkoutDownload) ...<Widget>[
              SizedBox(height: spacing.md),
              ElevatedButton.icon(
                onPressed: _generateWorkoutPdf,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusSuccess,
                  foregroundColor: AppColors.backgroundPrimary,
                  shadowColor: AppColors.statusSuccess.withOpacity(0.4),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _WorkoutDayDescriptor {
  const _WorkoutDayDescriptor({
    required this.displayName,
    required this.template,
  });

  final String displayName;
  final String template;
}

class _WorkoutDayPlan {
  const _WorkoutDayPlan({required this.name, required this.exercises});

  final String name;
  final List<_WorkoutExercise> exercises;
}

class _WorkoutExercise {
  const _WorkoutExercise(this.name, this.sets, this.reps, this.restPeriod);

  final String name;
  final String sets;
  final String reps;
  final String restPeriod;
}

class _PdfSummaryItem {
  const _PdfSummaryItem(this.label, this.value);

  final String label;
  final String value;
}
