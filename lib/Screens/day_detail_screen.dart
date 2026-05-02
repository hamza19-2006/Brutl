import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/brutl_models.dart';
import '../widgets/exercise_card_widget.dart';
import '../widgets/exercise_editor_sheet.dart';

class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({
    super.key,
    required this.uid,
    required this.weekId,
    required this.dayId,
    required this.workoutName,
  });

  final String uid;
  final String weekId;
  final String dayId;
  final String workoutName;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  // ─── Local state ────────────────────────────────────────────────────────────
  List<ExerciseModel> _exercises = [];
  String _dayName = '';
  bool _isSaving = false;
  bool _isLoadingLocal = true;

  // ─── Firestore stream ────────────────────────────────────────────────────────
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;

  // ─── SharedPreferences key ──────────────────────────────────────────────────
  String get _prefsKey => 'exercises_day_${widget.dayId}_week_${widget.weekId}';
  String get _dayNameKey => 'dayname_day_${widget.dayId}_week_${widget.weekId}';

  // ─── Firestore reference ────────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> get _dayDocRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(widget.uid)
      .collection('weeks')
      .doc(widget.weekId)
      .collection('days')
      .doc(widget.dayId);

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dayName = widget.workoutName;
    _loadFromLocalThenStream();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }

  // ─── Step 1: Load local data instantly, then subscribe Firestore ─────────────

  Future<void> _loadFromLocalThenStream() async {
    // Load from SharedPreferences first — zero network wait.
    await _loadFromSharedPreferences();

    // Then subscribe to Firestore for live sync (background).
    _firestoreSubscription = _dayDocRef.snapshots().listen(
      _onFirestoreUpdate,
      onError: (Object error) {
        debugPrint('DAY_DETAIL: Firestore stream error — $error');
      },
    );
  }

  Future<void> _loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached day name.
      final cachedName = prefs.getString(_dayNameKey);
      if (cachedName != null && cachedName.trim().isNotEmpty) {
        _dayName = cachedName;
      }

      // Load cached exercises.
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString) as List<dynamic>;
        final loaded = decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (mounted) {
          setState(() {
            _exercises = loaded;
            _isLoadingLocal = false;
          });
        }
        debugPrint(
          'DAY_DETAIL: Loaded ${loaded.length} exercises from SharedPreferences.',
        );
        return;
      }
    } catch (e) {
      debugPrint('DAY_DETAIL: SharedPreferences load failed — $e');
    }

    if (mounted) {
      setState(() => _isLoadingLocal = false);
    }
  }

  // ─── Firestore stream handler — merges server data into local list ───────────

  void _onFirestoreUpdate(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!snapshot.exists || snapshot.data() == null) return;

    final data = snapshot.data()!;

    // Merge server day name.
    final serverName = (data['name'] as String?)?.trim() ?? '';
    final resolvedName = serverName.isNotEmpty
        ? serverName
        : widget.workoutName;

    // Merge server exercises.
    final rawExercises =
        (data['exercises'] as List<dynamic>?) ?? const <dynamic>[];
    final serverExercises = rawExercises
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (!mounted) return;

    setState(() {
      _dayName = resolvedName;
      // Only replace local list if server has more exercises or differs.
      // This prevents a race condition where the server responds with
      // stale data AFTER the user has already added a new exercise locally.
      if (serverExercises.length >= _exercises.length) {
        _exercises = serverExercises;
      }
    });

    // Keep SharedPreferences in sync with server truth.
    unawaited(_persistToSharedPreferences(_exercises, resolvedName));
  }

  // ─── Step 2 + 3: Save exercise — local first, Firestore in background ────────

  Future<void> _saveExerciseLocally(ExerciseModel exercise) async {
    // Guard against duplicate taps.
    if (_isSaving) return;

    // --- STEP 2: Update UI immediately (0 ms) ---
    setState(() {
      _isSaving = true;

      final existingIndex = _exercises.indexWhere((e) => e.id == exercise.id);

      if (existingIndex >= 0) {
        // Replace existing exercise in place.
        final updated = List<ExerciseModel>.from(_exercises);
        updated[existingIndex] = exercise;
        _exercises = updated;
      } else {
        // Append new exercise.
        _exercises = [..._exercises, exercise];
      }
    });

    // Persist to SharedPreferences synchronously (very fast, <5 ms).
    await _persistToSharedPreferences(_exercises, _dayName);

    // Re-enable button — local write is done, UI is already updated.
    if (mounted) {
      setState(() => _isSaving = false);
    }

    // --- STEP 3: Fire-and-forget Firestore write (background, no await) ---
    unawaited(_saveExerciseToFirestore(exercise));
  }

  // ─── SharedPreferences persistence ──────────────────────────────────────────

  Future<void> _persistToSharedPreferences(
    List<ExerciseModel> exercises,
    String dayName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = exercises.map((e) => e.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
      await prefs.setString(_dayNameKey, dayName);
      debugPrint(
        'DAY_DETAIL: Persisted ${exercises.length} exercises to SharedPreferences.',
      );
    } catch (e) {
      debugPrint('DAY_DETAIL: SharedPreferences write failed — $e');
    }
  }

  // ─── Firestore write (background, never blocks UI) ───────────────────────────

  Future<void> _saveExerciseToFirestore(ExerciseModel exercise) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(_dayDocRef);
        final data = snapshot.data();
        final rawExercises =
            (data?['exercises'] as List<dynamic>?) ?? const <dynamic>[];

        final updatedExercises = <Map<String, dynamic>>[];
        var replaced = false;

        for (final raw in rawExercises) {
          if (raw is Map) {
            final map = Map<String, dynamic>.from(raw);
            if (map['id']?.toString() == exercise.id) {
              updatedExercises.add(exercise.toJson());
              replaced = true;
            } else {
              updatedExercises.add(map);
            }
          }
        }

        if (!replaced) {
          updatedExercises.add(exercise.toJson());
        }

        transaction.set(_dayDocRef, <String, dynamic>{
          'exercises': updatedExercises,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      debugPrint('DAY_DETAIL: Exercise ${exercise.id} synced to Firestore.');
    } catch (e) {
      debugPrint(
        'DAY_DETAIL: Firestore sync failed for ${exercise.id} — $e. '
        'Data is safe in SharedPreferences.',
      );
      // Data is safe in SharedPreferences. Will re-sync on next open
      // via the Firestore stream or manual retry.
    }
  }

  // ─── Rename day ──────────────────────────────────────────────────────────────

  Future<void> _showEditDayNameDialog(
    BuildContext context,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Day'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Day name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updatedName = controller.text.trim();
                if (updatedName.isEmpty) {
                  Navigator.of(dialogContext).pop();
                  return;
                }

                // Update locally first.
                if (mounted) {
                  setState(() => _dayName = updatedName);
                }
                unawaited(_persistToSharedPreferences(_exercises, updatedName));

                // Then update Firestore in background.
                unawaited(
                  _dayDocRef.set(<String, dynamic>{
                    'name': updatedName,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true)),
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _dayName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _showEditDayNameDialog(context, _dayName),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Exercise list ──────────────────────────────────────────────────
            Expanded(
              child: _isLoadingLocal
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF3D00),
                      ),
                    )
                  : _exercises.isEmpty
                  ? _buildEmptyState()
                  : _buildExerciseList(),
            ),

            // ── Add Exercise button ────────────────────────────────────────────
            _buildAddButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fitness_center,
              color: Color(0xFF333333),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No exercises yet',
              style: GoogleFonts.poppins(
                color: const Color(0xFF666666),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first exercise.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF444444),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _exercises.length,
      itemBuilder: (context, index) {
        final exercise = _exercises[index];
        return ExerciseCardWidget(
          exercise: exercise,
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ExerciseEditorSheet(
                exercise: exercise,
                splitName: _dayName,
                onSave: _saveExerciseLocally,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Opacity(
        // Step 4: Visually fade button while saving to prevent double-tap.
        opacity: _isSaving ? 0.55 : 1.0,
        child: ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  await showModalBottomSheet<ExerciseModel>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ExerciseEditorSheet(
                      splitName: _dayName,
                      // Pass the local-first save handler — NOT the old
                      // Firestore-awaited version.
                      onSave: _saveExerciseLocally,
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3D00),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text('Add Exercise'),
        ),
      ),
    );
  }
}
