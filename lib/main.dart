import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'Screens/auth/login_screen.dart';
import 'Screens/home_screen.dart';
import 'Screens/onboarding/onboarding_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/firebase_bootstrap.dart';
import 'providers/auth_provider.dart';
import 'providers/auth_validation_provider.dart';
import 'providers/brutl_user_provider.dart';
import 'providers/health_provider.dart';
import 'providers/workout_nutrition_provider.dart';
import 'providers/workout_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
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

class _AppWarmupGateState extends State<AppWarmupGate> {
  bool _didStartWarmup = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartWarmup) {
      return;
    }
    _didStartWarmup = true;
    unawaited(_warmupServices());
  }

  Future<void> _warmupServices() async {
    try {
      final workoutProvider = context.read<WorkoutProvider>();
      final nutritionProvider = context.read<WorkoutNutritionProvider>();

      await Hive.initFlutter();
      await Hive.openBox<String>('exercises');

      // Add check to ensure context is still valid
      if (!mounted) return;

      await workoutProvider.initialize();
      await nutritionProvider.initialize();

      if (mounted) {
        // Bind canonical user document for Settings module.
        await context.read<BrutlUserProvider>().bindToCurrentUser();
      }
    } catch (error) {
      debugPrint('BRUTL_BOOT: Startup warmup failed — $error');
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _BrutlLoadingScreen();
        }
        final currentUser =
            FirebaseAuth.instance.currentUser ?? authSnapshot.data;
        if (currentUser == null) {
          return const LoginScreen();
        }
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _BrutlLoadingScreen();
            }

            // Handle errors gracefully
            if (profileSnapshot.hasError) {
              return const _BrutlLoadingScreen();
            }

            final doc = profileSnapshot.data;
            final profileData = doc?.data();

            // Check for profile completion flag — prioritize new field name
            final isProfileComplete =
                doc != null &&
                doc.exists &&
                ((profileData?['is_profile_complete'] as bool?) ??
                    (profileData?['isProfileComplete'] as bool?) ??
                    false);

            // For brand new users with no profile data, route to onboarding
            if (doc == null || !doc.exists) {
              return const OnboardingScreen();
            }

            // If profile is not complete, show onboarding
            if (!isProfileComplete) {
              return const OnboardingScreen();
            }

            // Profile complete, show home
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _BrutlLoadingScreen extends StatelessWidget {
  const _BrutlLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF3D00))),
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
