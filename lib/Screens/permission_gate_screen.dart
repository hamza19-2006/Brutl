// ═══════════════════════════════════════════════════════════════════════════════
// PERMISSION GATE SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
//
// Displayed after onboarding but before the HomeScreen.
// Ensures the Activity Recognition permission is granted so step tracking
// works from the very first moment.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/health_provider.dart';
import 'home_screen.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _isRequesting = false;
  bool _didOpenSettings = false;

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

  /// When the user returns from OS Settings, re-check permission.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _didOpenSettings) {
      _didOpenSettings = false;
      _recheckAndNavigate();
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isRequesting = true);

    final stepProvider = context.read<StepProvider>();
    await stepProvider.requestPermissions();

    if (!mounted) return;

    if (stepProvider.hasPermission) {
      _navigateToHome();
    } else {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> _openSettings() async {
    _didOpenSettings = true;
    await openAppSettings();
  }

  Future<void> _recheckAndNavigate() async {
    final stepProvider = context.read<StepProvider>();
    await stepProvider.recheckPermissionAndStart();

    if (!mounted) return;

    if (stepProvider.hasPermission) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _skipForNow() {
    _navigateToHome();
  }

  @override
  Widget build(BuildContext context) {
    final stepProvider = context.watch<StepProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Icon ──
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3D00), Color(0xFFFF6B00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3D00).withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),

              const SizedBox(height: 36),

              // ── Title ──
              Text(
                'Track Your Steps',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
              ),

              const SizedBox(height: 16),

              // ── Description ──
              Text(
                'Brutl uses your device\'s motion sensor to silently '
                'count your steps — even when the app is closed.\n\n'
                'No battery-draining services. No persistent notifications. '
                'Just hardware-level step tracking.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9A9A9A),
                      fontSize: 14,
                      height: 1.6,
                    ),
              ),

              const Spacer(flex: 1),

              // ── Permanently denied banner ──
              if (stepProvider.permissionPermanentlyDenied)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFF3D00).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.settings_rounded,
                        color: Color(0xFFFF6B00),
                        size: 28,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Permission was denied permanently.\n'
                        'Please enable Activity Recognition\nin your device settings.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFBDBDBD),
                              fontSize: 13,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Open Settings'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF3D00),
                            side: const BorderSide(color: Color(0xFFFF3D00)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Grant Permission button ──
              if (!stepProvider.permissionPermanentlyDenied)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _requestPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3D00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Grant Permission',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

              const SizedBox(height: 14),

              // ── Skip for now ──
              TextButton(
                onPressed: _skipForNow,
                child: Text(
                  'Skip for now',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
