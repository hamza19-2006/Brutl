import 'package:flutter/material.dart';

import 'home/home_screen_ex_show.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: SafeArea(child: HomeScreenExShow()),
    );
  }
}
