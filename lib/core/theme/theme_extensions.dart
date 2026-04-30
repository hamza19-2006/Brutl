import 'package:flutter/material.dart';

extension BrutlThemeContextX on BuildContext {
  ThemeData get brutlTheme => Theme.of(this);
  ColorScheme get brutlColorsScheme => Theme.of(this).colorScheme;
  TextTheme get brutlTextTheme => Theme.of(this).textTheme;
}
