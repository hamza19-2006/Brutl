import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSaving = false;
  bool _isBackgroundReversed = false;

  // --- Page 1: Identity ---
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  Timer? _debounce;
  int _usernameCheckRequestId = 0;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameCheckError;

  // --- Page 2: Biometrics ---
  String _heightUnit = 'cm';
  final _heightCmCtrl = TextEditingController();
  int _heightFt = 5;
  int _heightIn = 8;

  String _weightUnit = 'kg';
  final _weightCtrl = TextEditingController();

  // --- Page 3: Workout Split ---
  String _splitTemplate = 'Push, Pull, Legs, Repeat';
  final List<String> _templateOptions = [
    'Push, Pull, Legs, Repeat',
    'Bro Split (1 muscle per day)',
    'Upper, Lower, Rest, Repeat',
    'Push, Pull, Legs, Upper, Lower',
    'Customize Split',
  ];
  double _customDays = 3;
  late List<TextEditingController> _customDayCtrls;

  // --- Page 4: Goals & Activity ---
  final _stepsCtrl = TextEditingController(text: '10000');
  String _bodyGoal = 'Weight Loss';

  // --- Page 5: Macros ---
  int _targetCalories = 2000;
  int _targetProtein = 150;
  int _targetCarbs = 200;
  int _targetFats = 60;
  bool _isCustomMacro = false;
  final _customCalCtrl = TextEditingController();
  final _customProCtrl = TextEditingController();
  final _customCarbCtrl = TextEditingController();
  final _customFatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _splitTemplate = _templateOptions.first;
    _customDayCtrls = _createSplitControllers(_splitTemplate);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _debounce?.cancel();
    _heightCmCtrl.dispose();
    _weightCtrl.dispose();
    for (var ctrl in _customDayCtrls) {
      ctrl.dispose();
    }
    _stepsCtrl.dispose();
    _customCalCtrl.dispose();
    _customProCtrl.dispose();
    _customCarbCtrl.dispose();
    _customFatCtrl.dispose();
    super.dispose();
  }

  List<String> _splitDefaultsForOption(String option) {
    switch (option) {
      case 'Push, Pull, Legs, Repeat':
        return <String>['Chest & Triceps', 'Back & Biceps', 'Leg & Shoulders'];
      case 'Bro Split (1 muscle per day)':
        return <String>['Chest ', 'Back ', 'Legs', 'Shoulders', 'Arms'];
      case 'Upper, Lower, Rest, Repeat':
        return <String>['Upper Body', 'Lower Body', 'Upper Body', 'Lower Body'];
      case 'Push, Pull, Legs, Upper, Lower':
        return <String>[
          'Chest & Triceps',
          'Back & Biceps',
          'Leg & Shoulders',
          'Upper Body',
          'Lower Body',
        ];
      case 'Customize Split':
        return <String>['Chest & Triceps', 'Back & Biceps', 'Leg & Shoulders'];
      default:
        return <String>['Chest & Triceps', 'Back & Biceps', 'Leg & Shoulders'];
    }
  }

  List<TextEditingController> _createSplitControllers(String option) {
    final defaults = _splitDefaultsForOption(option);
    return List<TextEditingController>.generate(
      defaults.length,
      (index) => TextEditingController(text: defaults[index]),
    );
  }

  void _applySplitTemplate(String option) {
    for (final controller in _customDayCtrls) {
      controller.dispose();
    }

    final defaults = _splitDefaultsForOption(option);
    _customDayCtrls = List<TextEditingController>.generate(
      defaults.length,
      (index) => TextEditingController(text: defaults[index]),
    );
    _customDays = defaults.length.toDouble();
    _splitTemplate = option;
  }

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final normalizedUsername = value.trim().toLowerCase();
    final requestId = ++_usernameCheckRequestId;
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
      _usernameCheckError = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || requestId != _usernameCheckRequestId) {
        return;
      }

      if (normalizedUsername.isEmpty) {
        if (!mounted || requestId != _usernameCheckRequestId) {
          return;
        }
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = null;
          _usernameCheckError = null;
        });
        return;
      }

      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: normalizedUsername)
            .limit(1)
            .get();

        if (!mounted || requestId != _usernameCheckRequestId) {
          return;
        }

        setState(() {
          _isUsernameAvailable = query.docs.isEmpty;
          _usernameCheckError = null;
        });
      } catch (error) {
        debugPrint('USERNAME_CHECK: Failed to validate username — $error');
        if (!mounted || requestId != _usernameCheckRequestId) {
          return;
        }
        setState(() {
          _isUsernameAvailable = false;
          _usernameCheckError = 'Error checking username';
        });
      } finally {
        if (!mounted || requestId != _usernameCheckRequestId) {
          return;
        }
        setState(() {
          _isCheckingUsername = false;
        });
      }
    });
  }

  void _calculateMacros() {
    if (_isCustomMacro) {
      _targetCalories = int.tryParse(_customCalCtrl.text) ?? 2000;
      _targetProtein = int.tryParse(_customProCtrl.text) ?? 150;
      _targetCarbs = int.tryParse(_customCarbCtrl.text) ?? 200;
      _targetFats = int.tryParse(_customFatCtrl.text) ?? 60;
      return;
    }

    double weightKg = _weightUnit == 'kg'
        ? (double.tryParse(_weightCtrl.text) ?? 70.0)
        : (double.tryParse(_weightCtrl.text) ?? 154.0) * 0.453592;

    double heightCm = _heightUnit == 'cm'
        ? (double.tryParse(_heightCmCtrl.text) ?? 170.0)
        : (_heightFt * 30.48) + (_heightIn * 2.54);

    if (weightKg <= 0) weightKg = 70.0;
    if (heightCm <= 0) heightCm = 170.0;

    // Simplified Mifflin-St Jeor (assuming male for base generic, a robust app might ask gender)
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * 25) + 5;
    double tdee = bmr * 1.375; // Lightly active

    double proMultiplier = 2.0;
    double fatMultiplier = 0.7;

    _targetCalories = tdee.round();
    _targetProtein = (weightKg * proMultiplier).round();
    _targetFats = (weightKg * fatMultiplier).round();
    _targetCarbs =
        ((_targetCalories - (_targetProtein * 4) - (_targetFats * 9)) / 4)
            .round();
    if (_targetCarbs < 0) _targetCarbs = 0;
  }

  Future<void> _finalizeOnboarding() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _calculateMacros();

    final customDays = _customDayCtrls.isNotEmpty
        ? _customDayCtrls
              .map((e) => e.text.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    final brutlUser = BrutlUser(
      uid: user.uid,
      displayName: _displayNameCtrl.text.trim(),
      username: _usernameCtrl.text.trim().toLowerCase(),
      height: _heightUnit == 'cm'
          ? (double.tryParse(_heightCmCtrl.text) ?? 0.0)
          : (_heightFt * 12 + _heightIn).toDouble(),
      heightUnit: _heightUnit,
      weight: double.tryParse(_weightCtrl.text) ?? 0.0,
      weightUnit: _weightUnit,
      dailySteps: int.tryParse(_stepsCtrl.text) ?? 10000,
      bodyGoal: _bodyGoal,
      workoutSplitTemplate: _splitTemplate,
      customSplitDays: customDays,
      targetCalories: _targetCalories,
      targetProtein: _targetProtein,
      targetCarbs: _targetCarbs,
      targetFats: _targetFats,
      isProfileComplete: false,
    );

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await docRef.set(brutlUser.toJson(), SetOptions(merge: true));
      await docRef.update({'isProfileComplete': true});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('step_goal', brutlUser.dailySteps);
      await prefs.setInt('calorie_goal', _targetCalories);
      await prefs.setInt('carbs_goal', _targetCarbs);
      await prefs.setInt('protein_goal', _targetProtein);
      await prefs.setInt('fats_goal', _targetFats);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('ONBOARDING: Failed to finalize profile — $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_displayNameCtrl.text.trim().isEmpty ||
          _usernameCtrl.text.trim().isEmpty ||
          _isCheckingUsername ||
          _isUsernameAvailable != true) {
        return; // Validation failed
      }
    } else if (_currentPage == 1) {
      if (_weightCtrl.text.trim().isEmpty) return;
      if (_heightUnit == 'cm' && _heightCmCtrl.text.trim().isEmpty) return;
    }

    // Pre-calculate macros BEFORE entering the macros page so TDEE is visible.
    if (_currentPage == 3) {
      _calculateMacros();
    }

    if (_currentPage < 5) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _finalizeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () {
                  if (_pageController.hasClients) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              )
            : null,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<Alignment>(
            tween: AlignmentTween(
              begin: _isBackgroundReversed
                  ? Alignment.bottomRight
                  : Alignment.topLeft,
              end: _isBackgroundReversed
                  ? Alignment.topLeft
                  : Alignment.bottomRight,
            ),
            duration: const Duration(seconds: 8),
            curve: Curves.easeInOutSine,
            onEnd: () {
              if (mounted) {
                setState(() {
                  _isBackgroundReversed = !_isBackgroundReversed;
                });
              }
            },
            builder: (context, alignment, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.breathingAuthGradient,
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    children: [
                      _buildIdentityPage(),
                      _buildBiometricsPage(),
                      _buildSplitPage(),
                      _buildGoalsPage(),
                      _buildMacrosPage(),
                      _buildReviewPage(),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(6, (index) {
          final isActive = index <= _currentPage;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFF3D00)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLastPage = _currentPage == 5;
    final isIdentityPage = _currentPage == 0;
    final isNextButtonEnabled =
        !_isSaving &&
        (!isIdentityPage ||
            (_displayNameCtrl.text.trim().isNotEmpty &&
                _usernameCtrl.text.trim().isNotEmpty &&
                !_isCheckingUsername &&
                _isUsernameAvailable == true));
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF3D00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: isNextButtonEnabled ? _nextPage : null,
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isLastPage ? 'Finish' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  // ===================== PAGE 1 =====================
  Widget _buildIdentityPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Your Identity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How should we address you?',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
          ),
          const SizedBox(height: 40),
          _buildGlassField(
            controller: _displayNameCtrl,
            label: 'Display Name',
            hint: 'e.g., John Doe',
          ),
          const SizedBox(height: 24),
          _buildGlassField(
            controller: _usernameCtrl,
            label: 'Unique Username',
            hint: 'e.g., john_doe123',
            prefix: '@',
            onChanged: _onUsernameChanged,
            suffix: _buildUsernameSuffix(),
          ),
          const SizedBox(height: 12),
          if (_isUsernameAvailable == false && _usernameCtrl.text.isNotEmpty)
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text(
                  'This username is already taken.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          if (_usernameCheckError != null && _usernameCtrl.text.isNotEmpty)
            const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text(
                  'Error checking username',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          if (_isUsernameAvailable == true && _usernameCtrl.text.isNotEmpty)
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Username available!',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildUsernameSuffix() {
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            color: Color(0xFFFF3D00),
            strokeWidth: 2,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // ===================== PAGE 2 =====================
  Widget _buildBiometricsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Biometrics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Used to calculate your unique macro profile.',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
          ),
          const SizedBox(height: 40),
          _buildSegmentedControl(
            value: _heightUnit,
            options: ['cm', 'ft/in'],
            onChanged: (v) => setState(() => _heightUnit = v),
          ),
          const SizedBox(height: 20),
          if (_heightUnit == 'cm')
            _buildGlassField(
              controller: _heightCmCtrl,
              label: 'Height',
              hint: '175',
              suffix: const Text('cm', style: TextStyle(color: Colors.white54)),
              keyboardType: TextInputType.number,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: _heightFt,
                    items: List.generate(5, (i) => i + 3),
                    onChanged: (v) => setState(() => _heightFt = v!),
                    label: 'Feet',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    value: _heightIn,
                    items: List.generate(12, (i) => i),
                    onChanged: (v) => setState(() => _heightIn = v!),
                    label: 'Inches',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 40),
          _buildSegmentedControl(
            value: _weightUnit,
            options: ['kg', 'lbs'],
            onChanged: (v) => setState(() => _weightUnit = v),
          ),
          const SizedBox(height: 20),
          _buildGlassField(
            controller: _weightCtrl,
            label: 'Weight',
            hint: '75',
            suffix: Text(
              _weightUnit,
              style: const TextStyle(color: Colors.white54),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  // ===================== PAGE 3 =====================
  Widget _buildSplitPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout Split',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How do you train?',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
          ),
          const SizedBox(height: 24),
          ..._templateOptions.map((option) {
            final isSelected = _splitTemplate == option;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _applySplitTemplate(option);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF3D00).withValues(alpha: 0.1)
                      : const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF3D00)
                        : const Color(0xFF2A2A2A),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? const Color(0xFFFF3D00)
                          : const Color(0xFF555555),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFBDBDBD),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_splitTemplate == 'Customize Split') ...[
            const SizedBox(height: 24),
            const Text(
              'Training days per week',
              style: TextStyle(color: Colors.white),
            ),
            Slider(
              value: _customDays,
              min: 1,
              max: 7,
              divisions: 6,
              activeColor: const Color(0xFFFF3D00),
              label: _customDays.round().toString(),
              onChanged: (val) {
                setState(() {
                  _customDays = val;
                  final intDays = val.toInt();
                  if (_customDayCtrls.length < intDays) {
                    _customDayCtrls.addAll(
                      List.generate(
                        intDays - _customDayCtrls.length,
                        (_) => TextEditingController(),
                      ),
                    );
                  } else if (_customDayCtrls.length > intDays) {
                    for (final controller in _customDayCtrls.sublist(intDays)) {
                      controller.dispose();
                    }
                    _customDayCtrls.removeRange(
                      intDays,
                      _customDayCtrls.length,
                    );
                  }
                });
              },
            ),
          ],
          if (_customDayCtrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...List.generate(_customDayCtrls.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildGlassField(
                  controller: _customDayCtrls[i],
                  label: 'Day ${i + 1}',
                  hint: 'e.g., Chest & Triceps',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ===================== PAGE 4 =====================
  Widget _buildGoalsPage() {
    final goals = ['Weight Loss', 'Body Recomposition', 'Weight Gain'];
    final goalIcons = ['🔥', '⚖️', '💪'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Goals & Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          _buildGlassField(
            controller: _stepsCtrl,
            label: 'Daily Step Goal',
            hint: '10000',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 40),
          const Text(
            'Primary Goal',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (i) {
              final isSelected = _bodyGoal == goals[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _bodyGoal = goals[i];
                    _calculateMacros();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF3D00).withValues(alpha: 0.1)
                          : const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF3D00)
                            : const Color(0xFF2A2A2A),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          goalIcons[i],
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          goals[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF9A9A9A),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===================== PAGE 5 =====================
  Widget _buildMacrosPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Macro Engine',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Calculated based on Mifflin-St Jeor.',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              setState(() {
                _isCustomMacro = false;
                _calculateMacros();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: !_isCustomMacro
                    ? const Color(0xFFFF3D00).withValues(alpha: 0.1)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !_isCustomMacro
                      ? const Color(0xFFFF3D00)
                      : const Color(0xFF2A2A2A),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_isCustomMacro
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: !_isCustomMacro
                        ? const Color(0xFFFF3D00)
                        : const Color(0xFF555555),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maintenance (TDEE)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your calculated daily energy expenditure',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isCustomMacro)
                    Text(
                      '$_targetCalories',
                      style: const TextStyle(
                        color: Color(0xFFFF3D00),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildMacroDashboard(),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              setState(() {
                _isCustomMacro = true;
                _customCalCtrl.text = _targetCalories.toString();
                _customProCtrl.text = _targetProtein.toString();
                _customCarbCtrl.text = _targetCarbs.toString();
                _customFatCtrl.text = _targetFats.toString();
              });
            },
            child: Row(
              children: [
                Icon(
                  _isCustomMacro
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _isCustomMacro
                      ? const Color(0xFFFF3D00)
                      : const Color(0xFF555555),
                ),
                const SizedBox(width: 12),
                Text(
                  'Customize My Own Macros',
                  style: TextStyle(
                    color: _isCustomMacro
                        ? Colors.white
                        : const Color(0xFF9A9A9A),
                    fontSize: 16,
                    fontWeight: _isCustomMacro
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (_isCustomMacro) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGlassField(
                    controller: _customCalCtrl,
                    label: 'Kcal',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _calculateMacros()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGlassField(
                    controller: _customProCtrl,
                    label: 'Pro (g)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _calculateMacros()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildGlassField(
                    controller: _customCarbCtrl,
                    label: 'Carbs (g)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _calculateMacros()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGlassField(
                    controller: _customFatCtrl,
                    label: 'Fats (g)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() => _calculateMacros()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroDashboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              '$_targetCalories',
              key: ValueKey<int>(_targetCalories),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Text(
            'KCAL / DAY',
            style: TextStyle(
              color: Color(0xFFFF3D00),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMacroStat('PROTEIN', '$_targetProtein\u200ag'),
              _buildMacroStat('CARBS', '$_targetCarbs\u200ag'),
              _buildMacroStat('FATS', '$_targetFats\u200ag'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7A7A7A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ===================== REUSABLE WIDGETS =====================
  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0D0D0),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              prefixText: prefix,
              prefixStyle: const TextStyle(
                color: Color(0xFFFF3D00),
                fontWeight: FontWeight.bold,
              ),
              suffix: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl({
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = value == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF3D00)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF9A9A9A),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0D0D0),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: items
                  .map(
                    (e) =>
                        DropdownMenuItem(value: e, child: Text(e.toString())),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewPage() {
    final customDays = _customDayCtrls.isNotEmpty
        ? _customDayCtrls
              .map((e) => e.text.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Your Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ensure everything is correct before finalizing.',
            style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('Name', _displayNameCtrl.text.trim()),
                _buildReviewRow(
                  'Username',
                  '@${_usernameCtrl.text.trim().toLowerCase()}',
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 32),
                _buildReviewRow(
                  'Height',
                  _heightUnit == 'cm'
                      ? '${_heightCmCtrl.text.trim()} cm'
                      : '$_heightFt ft $_heightIn in',
                ),
                _buildReviewRow(
                  'Weight',
                  '${_weightCtrl.text.trim()} $_weightUnit',
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 32),
                _buildReviewRow('Goal', _bodyGoal),
                const SizedBox(height: 16),
                const Text(
                  'Workout Split:',
                  style: TextStyle(color: Color(0xFF555555), fontSize: 14),
                ),
                const SizedBox(height: 4),
                ...customDays.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $day',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
