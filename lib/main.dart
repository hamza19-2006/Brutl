import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:first_projects/Screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/health_provider.dart';
import 'providers/workout_nutrition_provider.dart';
import 'providers/workout_provider.dart';
import 'Screens/auth/auth_screen.dart';
import 'Screens/onboarding/onboarding_screen.dart';
import 'Screens/permission_gate_screen.dart';
import 'services/background_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await Hive.openBox<String>('exercises');
  await Hive.openBox<int>('steps_history');

  // ── Initialize Workmanager for silent background step sync ──
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // Register a periodic task that runs approximately every 15 minutes.
  // Android enforces a minimum of 15 minutes for periodic tasks.
  await Workmanager().registerPeriodicTask(
    kBrutlStepSyncTask,
    kBrutlStepSyncTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.not_required,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 10),
  );
  debugPrint(
    'BRUTL_STEPS: Workmanager initialized & periodic task registered.',
  );

  final workoutProvider = WorkoutProvider();
  final stepProvider = StepProvider();
  final workoutNutritionProvider = WorkoutNutritionProvider();
  await workoutProvider.initialize();
  await stepProvider.initialize();
  await workoutNutritionProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<BrutlAuthProvider>(
          create: (_) => BrutlAuthProvider(),
        ),
        ChangeNotifierProvider<WorkoutProvider>.value(value: workoutProvider),
        ChangeNotifierProvider<StepProvider>.value(value: stepProvider),
        ChangeNotifierProvider<WorkoutNutritionProvider>.value(
          value: workoutNutritionProvider,
        ),
      ],
      child: const BrutlApp(),
    ),
  );
}

class BrutlApp extends StatelessWidget {
  const BrutlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brutl',
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
            ),
          );
        }
        if (snapshot.hasData) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0A0A0A),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF3D00)),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                final isProfileComplete =
                    data?['isProfileComplete'] as bool? ?? false;

                if (isProfileComplete) {
                  // ── Permission gate: check if step permission is granted ──
                  final stepProvider = context.read<StepProvider>();
                  if (!stepProvider.hasPermission) {
                    return const PermissionGateScreen();
                  }
                  return const HomeScreen();
                }
              }

              return const OnboardingScreen();
            },
          );
        }
        return const AuthScreen();
      },
    );
  }
}
