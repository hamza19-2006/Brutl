import 'package:flutter/material.dart';

/// Settings → Connected Apps.
/// Placeholder screen until integrations UI (Apple Health, Google Fit, Strava,
/// etc.) is ready.
class ConnectedAppsScreen extends StatelessWidget {
  const ConnectedAppsScreen({super.key});

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _card = Color(0xFF1A1A1A);
  static const Color _border = Color(0xFF2A2A2A);
  static const Color _accent = Color(0xFFFF3D00);
  static const Color _muted = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Connected Apps',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _card,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border, width: 1),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: _accent,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Not available yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Connect Apple Health, Google Fit, Strava and more.\n'
                  'We\'re wiring it up — stay tuned!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
