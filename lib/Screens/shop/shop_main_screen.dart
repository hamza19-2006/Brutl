import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/brutl_user_provider.dart';
import 'brutl_products_screen.dart';
import 'diet_workout_screen.dart';

class ShopMainScreen extends StatelessWidget {
  const ShopMainScreen({super.key});

  bool _isPakistan(String country) {
    return country.trim().toLowerCase() == 'pakistan';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<BrutlUserProvider>().user;
    final isPakistanUser = _isPakistan(user.country);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isPakistanUser)
            _ShopCard(
              title: 'Brutl Products',
              subtitle: 'Explore Brutl official products.',
              icon: Icons.shopping_bag_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BrutlProductsScreen(),
                  ),
                );
              },
            ),
          _ShopCard(
            title: 'Diet & Workout Plan',
            subtitle: 'Create a personalized plan with AI.',
            icon: Icons.fitness_center_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DietWorkoutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
