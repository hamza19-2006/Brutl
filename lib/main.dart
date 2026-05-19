import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'Screens/auth/login_screen.dart';
import 'Screens/home_screen.dart' hide AiCoachProvider;
import 'Screens/onboarding/onboarding_screen.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/auth_validation_provider.dart';
import 'providers/brutl_user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/health_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/water_provider.dart';
import 'providers/workout_nutrition_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/ai_coach_provider.dart';
import 'services/firebase_bootstrap.dart';
import 'services/step_sensor_service.dart';
import 'services/step_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait(<Future<void>>[
    FirebaseBootstrap.initialize(),
    Hive.initFlutter(),
  ]);
  runApp(const BrutlAppBootstrap());
}

class BrutlAppBootstrap extends StatelessWidget {
  const BrutlAppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BrutlAuthProvider>(
          create: (_) => BrutlAuthProvider(),
        ),
        ChangeNotifierProvider<AuthValidationProvider>(
          create: (_) => AuthValidationProvider(),
        ),
        ChangeNotifierProvider<WorkoutProvider>(
          create: (_) => WorkoutProvider(),
        ),
        ChangeNotifierProvider<StepProvider>(create: (_) => StepProvider()),
        ChangeNotifierProvider<WorkoutNutritionProvider>(
          create: (_) => WorkoutNutritionProvider(),
        ),
        ChangeNotifierProvider<BrutlUserProvider>(
          create: (_) => BrutlUserProvider(),
        ),
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (_) => SubscriptionProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<AiCoachProvider>(
          create: (_) => AiCoachProvider(),
        ),
        // ── NEW: Water Provider ─────────────────────────────────────────────
        ChangeNotifierProvider<WaterProvider>(create: (_) => WaterProvider()),
      ],
      child: const AppWarmupGate(),
    );
  }
}

class AppWarmupGate extends StatefulWidget {
  const AppWarmupGate({super.key});

  @override
  State<AppWarmupGate> createState() => _AppWarmupGateState();
}

class _AppWarmupGateState extends State<AppWarmupGate>
    with WidgetsBindingObserver {
  bool _didStartWarmup = false;
  StepProvider? _stepProviderRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stepProviderRef = context.read<StepProvider>();
    if (_didStartWarmup) return;
    _didStartWarmup = true;
    unawaited(_warmupServices());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final stepRef = _stepProviderRef;

    switch (state) {
      case AppLifecycleState.resumed:
        if (stepRef != null) unawaited(stepRef.refreshSteps());
        unawaited(StepService.instance.checkAndResetIfNewDay());
        unawaited(StepSensorService.instance.checkAndResetIfNewDay());
        // Also check water day reset on resume
        unawaited(context.read<WaterProvider>().checkAndResetIfNewDay());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _warmupServices() async {
    debugPrint('WARMUP: starting...');
    final sw = Stopwatch()..start();
    try {
      final workoutProvider = context.read<WorkoutProvider>();
      final nutritionProvider = context.read<WorkoutNutritionProvider>();
      final stepProvider = context.read<StepProvider>();
      final waterProvider = context.read<WaterProvider>();
      final brutlUserProvider = context.read<BrutlUserProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();
      debugPrint('WARMUP: providers read OK (${sw.elapsedMilliseconds}ms)');

      // ── Phase 1: independent LOCAL-only init in parallel ────────────────
      // Hive box open, step-service init and water-load all touch disk only;
      // running them serially wastes ~100–200 ms.
      await Future.wait(<Future<void>>[
        Hive.openBox<String>('exercises').then((_) {
          debugPrint('WARMUP: Hive box open OK');
        }),
        StepService.instance.initializeStepService().then((_) {
          debugPrint('WARMUP: step service init OK');
        }),
        waterProvider.loadFromLocal().then((_) {
          debugPrint('WARMUP: water provider load OK');
        }),
      ]);
      debugPrint('WARMUP: phase 1 done (${sw.elapsedMilliseconds}ms)');

      if (!mounted) return;

      // ── Phase 2: provider initializers that hit Firestore in parallel ───
      // workout / nutrition / brutlUser all read from Firestore; running them
      // sequentially is the single biggest startup slowdown.
      await Future.wait(<Future<void>>[
        stepProvider.initialize().then((_) {
          debugPrint('WARMUP: step provider init OK');
        }),
        workoutProvider.initialize().then((_) {
          debugPrint('WARMUP: workout provider init OK');
        }),
        nutritionProvider.initialize().then((_) {
          debugPrint('WARMUP: nutrition provider init OK');
        }),
        brutlUserProvider.bindToCurrentUser().then((_) {
          debugPrint('WARMUP: BrutlUser bind OK');
        }),
        subscriptionProvider.bindToCurrentUser().then((_) {
          debugPrint('WARMUP: Subscription bind OK');
        }),
      ]);
      debugPrint('WARMUP: complete (${sw.elapsedMilliseconds}ms total)');
    } catch (error, stack) {
      debugPrint('BRUTL_BOOT: Startup warmup failed — $error');
      debugPrint('BRUTL_BOOT: Stack — $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const BrutlApp();
  }
}

class BrutlApp extends StatelessWidget {
  const BrutlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brutl',
      theme: AppTheme.darkTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _profileUid;
  Future<DocumentSnapshot<Map<String, dynamic>>?>? _profileFuture;
  Timer? _watchdog;
  bool _watchdogExpired = false;

  @override
  void initState() {
    super.initState();
    // Hard safety net: if the whole auth/profile flow takes longer than 8s
    // for any reason (Firebase init issues, App Check, network), we force
    // the app to leave the loading screen.
    _watchdog = Timer(const Duration(seconds: 8), () {
      if (!mounted || _watchdogExpired) return;
      debugPrint('AUTH_WRAPPER: WATCHDOG fired — forcing past loading screen');
      setState(() => _watchdogExpired = true);
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadProfile(
    String uid,
  ) async {
    // Try cache first — instant return if the user has opened the app before.
    try {
      final cached = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
      if (cached.exists) {
        debugPrint('AUTH_WRAPPER: profile loaded from CACHE');
        // Fire-and-forget a background refresh so data stays fresh.
        unawaited(
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 10))
              .catchError(
                (Object _) => FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get(),
              ),
        );
        return cached;
      }
    } catch (e) {
      debugPrint('AUTH_WRAPPER: cache miss/err ($e), trying server');
    }
    // No cache → server with a 6-second guard.
    try {
      final fresh = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('AUTH_WRAPPER: server fetch timed out');
              throw TimeoutException('Profile fetch timed out');
            },
          );
      debugPrint('AUTH_WRAPPER: profile loaded from SERVER');
      return fresh;
    } catch (e) {
      debugPrint('AUTH_WRAPPER: profile fetch failed: $e');
      return null;
    }
  }

  void _ensureProfileFuture(String uid) {
    if (_profileUid == uid && _profileFuture != null) return;
    _profileUid = uid;
    _profileFuture = _loadProfile(uid);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('AUTH_WRAPPER: building... (watchdogExpired=$_watchdogExpired)');
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        debugPrint(
          'AUTH_WRAPPER: auth state=${authSnapshot.connectionState}, '
          'hasData=${authSnapshot.hasData}, user=${authSnapshot.data?.uid}',
        );
        final currentUser =
            FirebaseAuth.instance.currentUser ?? authSnapshot.data;

        if (currentUser == null) {
          // If watchdog expired and we still have no user → just show login.
          if (authSnapshot.connectionState == ConnectionState.waiting &&
              !_watchdogExpired) {
            return const _BrutlLoadingScreen(message: 'Checking auth…');
          }
          debugPrint('AUTH_WRAPPER: no user, showing LoginScreen');
          return const LoginScreen();
        }

        _ensureProfileFuture(currentUser.uid);
        debugPrint('AUTH_WRAPPER: user=${currentUser.uid}, fetching profile');
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            debugPrint(
              'AUTH_WRAPPER: profile state=${profileSnapshot.connectionState}, '
              'hasError=${profileSnapshot.hasError}',
            );
            if (profileSnapshot.connectionState == ConnectionState.waiting &&
                !_watchdogExpired) {
              return const _BrutlLoadingScreen(message: 'Loading profile…');
            }
            // Either we have a result, or the watchdog forced us through.
            final doc = profileSnapshot.data;
            final profileData = doc?.data();
            final isProfileComplete =
                doc != null &&
                doc.exists &&
                ((profileData?['is_profile_complete'] as bool?) ??
                    (profileData?['isProfileComplete'] as bool?) ??
                    false);
            debugPrint(
              'AUTH_WRAPPER: docExists=${doc?.exists}, isProfileComplete=$isProfileComplete',
            );
            // If the profile fetch errored or timed out, assume the user has
            // a valid profile (they're already logged in) and let them in.
            if (profileSnapshot.hasError || doc == null) {
              debugPrint(
                'AUTH_WRAPPER: no doc/error — falling through to HomeScreen',
              );
              return const HomeScreen();
            }
            if (!doc.exists || !isProfileComplete) {
              return const OnboardingScreen();
            }
            debugPrint('AUTH_WRAPPER: showing HomeScreen');
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _BrutlLoadingScreen extends StatelessWidget {
  const _BrutlLoadingScreen({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF3D00)),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InfoCollectionScreen extends StatelessWidget {
  const InfoCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingScreen();
  }
}
