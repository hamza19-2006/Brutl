import 'package:flutter/material.dart';

class BrutlProductsScreen extends StatelessWidget {
  const BrutlProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brutl Products')),
      body: const Center(
        child: Text(
          'Coming Soon',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
