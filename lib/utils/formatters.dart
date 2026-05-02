String formatWeight(double value, String unit) {
  final normalizedUnit = unit.trim().isEmpty ? 'Kg' : unit.trim();
  final formatted =
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
  return '$formatted $normalizedUnit';
}
