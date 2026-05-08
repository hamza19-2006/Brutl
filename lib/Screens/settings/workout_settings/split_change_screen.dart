import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/workout_provider.dart';
import '../widgets/settings_widgets.dart';

class SplitChangeScreen extends StatefulWidget {
  const SplitChangeScreen({super.key});

  @override
  State<SplitChangeScreen> createState() => _SplitChangeScreenState();
}

class _SplitChangeScreenState extends State<SplitChangeScreen> {
  static const List<String> _templateOptions = [
    'Push, Pull, Legs, Repeat',
    'Bro Split (1 muscle per day)',
    'Upper, Lower, Rest, Repeat',
    'Push, Pull, Legs, Upper, Lower',
    'Customize Split',
  ];

  late int _selectedIndex;
  double _customDays = 3;
  late List<TextEditingController> _customDayCtrls;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentSplit = context.read<WorkoutProvider>().selectedWorkoutSplit;
    _selectedIndex = _indexFromSplitName(currentSplit);
    if (_selectedIndex == 4) {
      _customDayCtrls = List.generate(
        _customDays.toInt(),
        (i) => TextEditingController(text: 'Day ${i + 1}'),
      );
    } else {
      _customDayCtrls = [];
    }
  }

  @override
  void dispose() {
    for (final c in _customDayCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  int _indexFromSplitName(String splitName) {
    switch (splitName) {
      case 'Push/Pull/Legs':
        return 0;
      case 'Bro Split':
        return 1;
      case 'Upper/Lower':
        return 2;
      case 'Push, Pull, Legs, Upper, Lower':
        return 3;
      default:
        return 4;
    }
  }

  List<String> _defaultsForOption(String option) {
    switch (option) {
      case 'Push, Pull, Legs, Repeat':
        return [
          'Chest & Triceps',
          'Back & Biceps',
          'Legs & Shoulders',
          'Chest & Triceps',
          'Back & Biceps',
          'Legs & Shoulders',
          'Rest',
        ];
      case 'Bro Split (1 muscle per day)':
        return ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Rest Day', 'Rest Day'];
      case 'Upper, Lower, Rest, Repeat':
        return ['Upper A', 'Lower A', 'Rest Day', 'Upper B', 'Lower B', 'Rest Day', 'Rest Day'];
      case 'Push, Pull, Legs, Upper, Lower':
        return [
          'Chest & Triceps',
          'Back & Biceps',
          'Legs & Shoulders',
          'Rest Day',
          'Upper',
          'Lower',
          'Rest Day',
        ];
      default:
        return List.generate(_customDays.toInt(), (i) => 'Day ${i + 1}');
    }
  }

  String _normalizeSplitName(String option) {
    switch (option) {
      case 'Push, Pull, Legs, Repeat':
        return 'Push/Pull/Legs';
      case 'Bro Split (1 muscle per day)':
        return 'Bro Split';
      case 'Upper, Lower, Rest, Repeat':
        return 'Upper/Lower';
      case 'Push, Pull, Legs, Upper, Lower':
        return 'Push, Pull, Legs, Upper, Lower';
      default:
        return 'Customize Split';
    }
  }

  void _selectOption(int index) {
    for (final c in _customDayCtrls) {
      c.dispose();
    }
    setState(() {
      _selectedIndex = index;
      if (index == 4) {
        _customDayCtrls = List.generate(
          _customDays.toInt(),
          (i) => TextEditingController(text: 'Day ${i + 1}'),
        );
      } else {
        _customDayCtrls = [];
      }
    });
  }

  void _updateCustomDayCount(double value) {
    final newCount = value.toInt();
    final oldCount = _customDayCtrls.length;
    if (newCount == oldCount) return;
    setState(() {
      if (newCount > oldCount) {
        for (var i = oldCount; i < newCount; i++) {
          _customDayCtrls.add(TextEditingController(text: 'Day ${i + 1}'));
        }
      } else {
        for (var i = oldCount - 1; i >= newCount; i--) {
          _customDayCtrls[i].dispose();
          _customDayCtrls.removeAt(i);
        }
      }
      _customDays = value;
    });
  }

  List<String> _getNewDaysList() {
    if (_selectedIndex == 4) {
      return _customDayCtrls
          .map((c) => c.text.trim().isEmpty ? 'Rest' : c.text.trim())
          .toList();
    }
    return _defaultsForOption(_templateOptions[_selectedIndex]);
  }

  Future<void> _onSaveSplit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.statusError),
        ),
        title: Text(
          'Warning: Destructive Action',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Changing your split will permanently delete your current split and '
          'wipe ALL associated exercise lists. Do you want to proceed?',
          style: AppTextStyles.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, Change Split',
              style: AppTextStyles.headingSmall(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newDays = _getNewDaysList();
    final splitName = _normalizeSplitName(_templateOptions[_selectedIndex]);

    setState(() => _isSaving = true);

    context.read<WorkoutProvider>().wipeAndReplaceSplit(newDays);
    unawaited(_firebaseWipeSplit(newDays, splitName));

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Split updated successfully.'),
          backgroundColor: AppColors.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    Navigator.of(context).pop();
  }

  static Future<void> _firebaseWipeSplit(
    List<String> newDays,
    String splitName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final exercisesBox = Hive.box<String>('exercises');

      final workoutsSnap = await firestore
          .collection('users')
          .doc(uid)
          .collection('workouts')
          .get();

      final batch = firestore.batch();
      for (final doc in workoutsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.set(
        firestore.collection('users').doc(uid),
        <String, dynamic>{
          'workout_split_template': splitName,
          'workout_master_template': newDays,
          'custom_split_days': newDays,
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      await exercisesBox.clear();
    } catch (e) {
      debugPrint('SPLIT_CHANGE: Firebase wipe-split failed — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = _templateOptions[_selectedIndex];
    final previewDays =
        _selectedIndex != 4 ? _defaultsForOption(selectedOption) : <String>[];

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Split Change'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('SELECT SPLIT', style: AppTextStyles.labelLarge()),
                    const SizedBox(height: AppSpacing.sm),
                    ...List.generate(_templateOptions.length, (i) {
                      final isSelected = _selectedIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: GestureDetector(
                          onTap: () => _selectOption(i),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.accentSoft
                                  : AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.borderRadiusMedium,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accentPrimary
                                    : AppColors.borderDefault,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _templateOptions[i],
                                    style: AppTextStyles.headingSmall(
                                      color: isSelected
                                          ? AppColors.accentPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.accentPrimary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_selectedIndex == 4) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('TRAINING DAYS', style: AppTextStyles.labelLarge()),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${_customDays.toInt()} days / week',
                        style: AppTextStyles.bodyLarge(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.accentPrimary,
                          inactiveTrackColor: AppColors.backgroundQuaternary,
                          thumbColor: AppColors.accentPrimary,
                          overlayColor: AppColors.accentGlow,
                          valueIndicatorColor: AppColors.accentPrimary,
                        ),
                        child: Slider(
                          value: _customDays,
                          min: 1,
                          max: 7,
                          divisions: 6,
                          label: '${_customDays.toInt()}',
                          onChanged: _updateCustomDayCount,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('DAY NAMES', style: AppTextStyles.labelLarge()),
                      const SizedBox(height: AppSpacing.sm),
                      ...List.generate(
                        _customDayCtrls.length,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: TextField(
                            controller: _customDayCtrls[i],
                            textCapitalization: TextCapitalization.words,
                            maxLength: 30,
                            decoration: InputDecoration(
                              labelText: 'Day ${i + 1}',
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('SPLIT PREVIEW', style: AppTextStyles.labelLarge()),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusLarge,
                          ),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Column(
                          children: List.generate(previewDays.length, (i) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    i < previewDays.length - 1
                                        ? AppSpacing.sm
                                        : 0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundQuaternary,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.borderRadiusSmall,
                                      ),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: AppTextStyles.labelLarge(
                                        color: AppColors.accentPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      previewDays[i],
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _onSaveSplit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.backgroundQuaternary,
                    disabledForegroundColor: AppColors.textTertiary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusMedium,
                      ),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Split',
                          style: AppTextStyles.headingSmall(
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
