import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/workout_provider.dart';
import '../widgets/settings_widgets.dart';

class EditDaysScreen extends StatefulWidget {
  const EditDaysScreen({super.key});

  @override
  State<EditDaysScreen> createState() => _EditDaysScreenState();
}

class _EditDaysScreenState extends State<EditDaysScreen> {
  int _selectedWeekIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, 'Edit Days'),
      body: SafeArea(
        child: Consumer<WorkoutProvider>(
          builder: (context, provider, _) {
            final totalWeeks = provider.totalProgramWeeks;
            final dayNames = provider.customSplitDays;

            if (_selectedWeekIndex >= totalWeeks) {
              _selectedWeekIndex = totalWeeks > 0 ? totalWeeks - 1 : 0;
            }

            return Column(
              children: [
                // Week selector tabs
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    itemCount: totalWeeks,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedWeekIndex == index;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedWeekIndex = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF3D00)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(20),
                            border: isSelected
                                ? null
                                : Border.all(color: const Color(0xFF2A2A2A)),
                          ),
                          child: Text(
                            'Week ${index + 1}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF888888),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Day rows loaded from Firestore
                Expanded(
                  child: dayNames.isEmpty
                      ? Center(
                          child: Text(
                            'No split configured yet.',
                            style: AppTextStyles.bodyMedium(),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                          itemCount: dayNames.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final weekNumber = _selectedWeekIndex + 1;
                            final weekId = 'week_$weekNumber';
                            final dayId = 'day_${index + 1}';
                            final dayName = dayNames[index];
                            return _FirestoreDayRow(
                              weekId: weekId,
                              dayId: dayId,
                              dayName: dayName,
                              dayIndex: index,
                              weekIndex: _selectedWeekIndex,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// A single day row that reads its exercise count live from Firestore
// ---------------------------------------------------------------------------

class _FirestoreDayRow extends StatelessWidget {
  const _FirestoreDayRow({
    required this.weekId,
    required this.dayId,
    required this.dayName,
    required this.dayIndex,
    required this.weekIndex,
  });

  final String weekId;
  final String dayId;
  final String dayName;
  final int dayIndex;
  final int weekIndex;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _dayDocRef {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc(weekId)
        .collection('days')
        .doc(dayId);
  }

  @override
  Widget build(BuildContext context) {
    final docRef = _dayDocRef;
    if (docRef == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final exercises = (data?['exercises'] as List<dynamic>?) ?? const [];
        final exerciseCount = exercises.length;

        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _FirestoreEditExercisesScreen(
                      weekId: weekId,
                      dayId: dayId,
                      dayName: dayName,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusMedium,
                    ),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayName, style: AppTextStyles.headingSmall()),
                      const SizedBox(height: 4),
                      Text(
                        '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                        style: AppTextStyles.bodySmall(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit,
                color: AppColors.textSecondary,
                size: 20,
              ),
              tooltip: 'Rename day',
              onPressed: () => _showRenameDialog(context, docRef),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.statusError,
                size: 20,
              ),
              tooltip: 'Clear exercises',
              onPressed: () =>
                  _showClearConfirm(context, docRef, exerciseCount),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    final controller = TextEditingController(text: dayName);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        title: Text('Rename Day', style: AppTextStyles.headingMedium()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter day name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              Navigator.of(ctx).pop();
              if (newName.isEmpty || newName == dayName) return;
              await docRef.set(<String, dynamic>{
                'name': newName,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Day renamed to "$newName".'),
                      backgroundColor: AppColors.statusSuccess,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              }
            },
            child: Text(
              'Save',
              style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showClearConfirm(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    int exerciseCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.statusError),
        ),
        title: Text(
          'Clear Day Exercises',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Are you sure? This will delete all $exerciseCount exercise${exerciseCount == 1 ? '' : 's'} '
          'under "$dayName". The day itself remains.',
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
              'Yes, Clear',
              style: AppTextStyles.headingSmall(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await docRef.set(<String, dynamic>{
      'exercises': <dynamic>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Exercises for "$dayName" cleared.'),
            backgroundColor: AppColors.statusSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Full exercise-edit screen backed entirely by Firestore
// ---------------------------------------------------------------------------

class _FirestoreEditExercisesScreen extends StatelessWidget {
  const _FirestoreEditExercisesScreen({
    required this.weekId,
    required this.dayId,
    required this.dayName,
  });

  final String weekId;
  final String dayId;
  final String dayName;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weeks')
        .doc(weekId)
        .collection('days')
        .doc(dayId);
  }

  @override
  Widget build(BuildContext context) {
    final docRef = _docRef;
    if (docRef == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: buildSettingsAppBar(context, '$dayName Exercises'),
        body: const Center(child: Text('Not signed in.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: buildSettingsAppBar(context, '$dayName Exercises'),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentPrimary,
                ),
              );
            }

            final data = snapshot.data?.data();
            final rawExercises =
                (data?['exercises'] as List<dynamic>?) ?? const [];
            final exercises = rawExercises
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            if (exercises.isEmpty) {
              return Center(
                child: Text(
                  'No exercises for this day.',
                  style: AppTextStyles.bodyMedium(),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              itemCount: exercises.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final ex = exercises[index];
                final name = ex['name']?.toString() ?? 'Exercise';
                final sets = ex['sets']?.toString() ?? '—';
                final reps = ex['reps']?.toString() ?? '—';

                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusMedium,
                          ),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppTextStyles.headingSmall()),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '$sets sets · $reps reps',
                              style: AppTextStyles.bodySmall(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      tooltip: 'Rename exercise',
                      onPressed: () => _showRenameDialog(
                        context,
                        docRef,
                        exercises,
                        index,
                        name,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.statusError,
                        size: 20,
                      ),
                      tooltip: 'Delete exercise',
                      onPressed: () => _showDeleteDialog(
                        context,
                        docRef,
                        exercises,
                        index,
                        name,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    List<Map<String, dynamic>> exercises,
    int index,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        title: Text('Rename Exercise', style: AppTextStyles.headingMedium()),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              Navigator.of(ctx).pop();
              if (newName.isEmpty || newName == currentName) return;
              final updated = List<Map<String, dynamic>>.from(exercises);
              updated[index] = {...updated[index], 'name': newName};
              await docRef.set(<String, dynamic>{
                'exercises': updated,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Exercise renamed to "$newName".'),
                      backgroundColor: AppColors.statusSuccess,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              }
            },
            child: Text(
              'Save',
              style: AppTextStyles.headingSmall(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
    List<Map<String, dynamic>> exercises,
    int index,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLarge),
          side: const BorderSide(color: AppColors.statusError),
        ),
        title: Text(
          'Delete Exercise',
          style: AppTextStyles.headingMedium(color: AppColors.statusError),
        ),
        content: Text(
          'Delete "$name" from this day?',
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
              'Delete',
              style: AppTextStyles.headingSmall(color: AppColors.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final updated = List<Map<String, dynamic>>.from(exercises)..removeAt(index);
    await docRef.set(<String, dynamic>{
      'exercises': updated,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('"$name" deleted.'),
            backgroundColor: AppColors.statusSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}
